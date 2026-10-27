// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
 * ═════════════════════════════════════════════════════════════════════════════
 * BeTrueCore — IBeTrueCoreAntiCollusion.sol
 * Interface: Anti-Collusion Layer (L1)
 *
 * Author:  Farman Guliyev (Safarnur)
 * ORCID:   0009-0004-4841-594X
 * GitHub:  github.com/Dede-Qorqud/BeTrueCore
 * Version: 0.1
 * ═════════════════════════════════════════════════════════════════════════════
 *
 * PURPOSE
 * ───────
 * This interface defines the contract boundary of BeTrueCore's L1 anti-collusion
 * layer. It is implemented by Poll.sol and consumed by BeTrueCoreCore.sol.
 *
 * POSITION IN ARCHITECTURE
 * ────────────────────────
 *
 *   L0 (Identity)
 *     NINIdentityProof.circom → nullifier + ZK proof
 *         ↓
 *   L1 (Proofs) ← THIS INTERFACE
 *     NINNullifierRegistry.sol  — verifies ZK identity proof, registers nullifier
 *     Poll.sol                  — accepts encrypted messages, enforces time lock
 *     IBeTrueCoreAntiCollusion  — contract boundary between L1 and L2
 *         ↓
 *   L2 (Execution)
 *     BeTrueCoreCore.sol — session lifecycle
 *     VWUEngine.sol      — vote weight computation
 *
 * CORE PROPERTY — RECEIPT-FREENESS
 * ─────────────────────────────────
 * A participant can change their binary choice before the time lock, up to
 * the per-participant cap in PollConfig.max_messages — not without bound. The
 * cap is part of this property and not a detail beside it: once it is spent,
 * the choice standing at that moment is the final one. Only the final choice
 * counts. No intermediate choice can serve as proof of what was chosen — all
 * intermediate states are equally plausible. Buying a STATED choice is
 * therefore pointless while the cap lasts: the seller can state anything and
 * change it afterwards. Buying the MESSAGE KEY is not — see the limit below.
 *
 *   Choice 1 (T=0):   EncMsg(key_1, OPTION_A)
 *   Choice 2 (T=30):  EncMsg(key_2, OPTION_B)   ← key_1 invalidated
 *   Choice 3 (T=45):  EncMsg(key_3, OPTION_A)   ← key_2 invalidated
 *   TIME LOCK (T=60): only OPTION_A via key_3 counted
 *
 * The limit of this property, stated plainly. What it hides is the content
 * of each message. What it does not hide is the diagram above: three calls
 * at T=0, T=30 and T=45, each sent from the participant's own address and
 * visible on the network before any block holds it. A coercer does not need
 * the content. "Send it while I watch, and do not come back to it" is a
 * demand he can check by looking — the absence of a later message is as
 * visible as its presence. Rotation protects what was chosen; it does not
 * protect the fact of rotating, and that is what this demand rests on.
 * The second demand it does not answer is "hand me the key". A coercer
 * holding the message key sends the last message himself, and rotation then
 * works for him exactly as it would for the participant. The literature
 * closes this with a fake key the coercer cannot tell from a real one
 * (Juels, Catalano and Jakobsson, coercion-resistant elections); no such
 * primitive is established here. What the protocol holds is therefore
 * narrower than resistance to coercion: a defector is not identified,
 * inside the protocol perimeter, provided each participant chooses once and
 * with their own key. Being watched at the moment of choosing, and handing
 * the key over, lie outside it. Audit lens B6.
 * Submitting through a third-party relayer does not remove the sender from
 * view. Under ERC-4337 the submitted object carries the originating account
 * in its `sender` field — present in the public mempool, in the on-chain
 * PackedUserOperation, and in the signed hash — so relaying moves the
 * observable identifier to the account, where it persists across sessions,
 * rather than removing it. The role that carries the cost of submission in
 * ERC-4337 has no counterpart here: a BeTrueCore participant pays nothing to
 * enter a session or to send a message. No primitive closing this is
 * established here. See the
 * note at MessagePublished below, and AUTHORITY_CHAIN.md §11. Audit lens B5.
 *
 * ERC-8281 INTEGRATION POINT (Damon Zwicker, OCP)
 * ─────────────────────────────────────────────────
 * ERC-8281 (Observation Commitment Protocol) attaches to two points:
 *
 *   L1 attachment: the VoteProof observation envelope
 *     When a participant joins a poll, ERC-8281 wraps the moment of
 *     entry with an independently verifiable commitment — without
 *     accessing BeTrueCore's private VWU inputs or protocol semantics.
 *     What it does commit to is the moment itself: this nullifier, this
 *     poll, this point in time, recorded a second time and outside our
 *     chain. That is the purpose of the envelope, and it is also the
 *     material lens B5 is about — timing and order. Neither record adds
 *     anything the join call does not already show in the open; the point
 *     worth stating is that the exposure exists in two places, so any
 *     later decision about it has to cover both.
 *
 *   L3 attachment: the two-point time-lock commitment
 *     Before lock + after reveal = two ERC-8281 commitments.
 *     Any external observer can verify the time-lock was honored.
 *
 * See: docs/MACI_ENGINEER_PACKAGE.md for full integration guide.
 * ═════════════════════════════════════════════════════════════════════════════
 */

/// @title IBeTrueCoreAntiCollusion
/// @notice Interface for BeTrueCore's L1 anti-collusion layer (Circom/Groth16 MACI pattern)
interface IBeTrueCoreAntiCollusion {

    // ══════════════════════════════════════════════════════════════════════
    // ENUMS
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Current state of a poll
    /// @dev Only two of these are ever written to storage: openPoll writes
    ///      ACTIVE, finalizePoll writes FINALIZED. PENDING and LOCKED are
    ///      derived from the declared window by getPollState — they are how a
    ///      stored ACTIVE reads before start_time and after end_time.
    ///      Reordering the members is free while nothing is deployed; once a
    ///      contract holds stored values it would not be.
    enum PollState {
        PENDING,    // opened, declared window has not started yet
        ACTIVE,     // inside the window, accepting joins and messages
        LOCKED,     // window closed, awaiting coordinator finalization
        FINALIZED   // result published with ZK correctness proof
    }

    // ══════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Encrypted message submitted by a participant
    /// @dev Stored as events only — not in contract storage.
    ///      Choice is hidden until coordinator decrypts off-chain.
    struct Message {
        /// @dev Ciphertext: choice encrypted with coordinator's public key
        ///      Coordinator decrypts off-chain after time lock
        ///
        ///      The plaintext domain is two values and nothing else: Option A
        ///      or Option B. The field is `bytes` because a ciphertext is, not
        ///      because the content is open — a participant can place any
        ///      payload here and the chain cannot tell. The obligation is
        ///      therefore on the off-chain processing, in two parts. A
        ///      plaintext that is not one of the two values is discarded at
        ///      decryption and counts as no message. And no payload from this
        ///      field, decrypted or raw, is ever passed to a language model.
        ///      The first part keeps a malformed payload out of the tally. The
        ///      second keeps this field from becoming an input surface for the
        ///      L5 observation agents — which is the one exposure a binary
        ///      channel is otherwise free of, and the reason this layer is not
        ///      where the injection boundary sits. Audit lens B1.
        bytes   encrypted_data;

        /// @dev Participant's ephemeral public key for this message.
        ///      Key rotation: each new message may use a different ephemeral key.
        ///      Only the last valid key's message is counted.
        uint256[2] ephemeral_pk;
    }

    /// @notice Poll configuration set at opening
    /// @dev start_time is the declared opening of the window, not the moment
    ///      openPoll happened to be called. The two coincide when a poll is
    ///      opened to start at once; they differ when a session is announced
    ///      ahead of time, which is the ordinary case for a daily dilemma.
    ///      Both edges are enforced — see whenActive and isPollActive in
    ///      Poll.sol.
    struct PollConfig {
        /// @dev A 32-byte commitment to the dilemma text. The text itself is
        ///      written by participants — it is a prompt the community
        ///      selected into the session agenda — and it lives off-chain,
        ///      where the L5 observation agents read it. That makes it the
        ///      input surface set out in docs/AUTHORITY_CHAIN.md, §13: text an
        ///      outsider can place in front of a language model by taking
        ///      part. What this field contributes is worth stating exactly: it
        ///      binds which text was in force for this poll, so a report about
        ///      the session can afterwards be checked against the text that
        ///      was actually read, and a text substituted later does not
        ///      match. It does not make the text safe to read.
        ///      Open item, recorded in §13: the commitment function and the
        ///      place the text is published are fixed nowhere in the code.
        ///      Audit lens B1.
        bytes32 dilemma_hash;
        uint256 start_time;       // declared start of the window
        uint256 end_time;         // declared end; start_time + duration
        /// @dev Anti-spam cap PER PARTICIPANT (default: 20). Note the second
        ///      thing it caps: re-choice. Receipt-freeness rests on being able
        ///      to send a later message, and after the twentieth that ability
        ///      is gone for the rest of the window — a coercer who demands the
        ///      cap be spent in front of him leaves the participant holding a
        ///      final choice the coercer picked. The cap is needed against
        ///      spam and the number is a pilot value; the cost is stated here
        ///      so the trade-off is visible rather than discovered.
        ///      Audit lens B6.
        uint256 max_messages;
        uint256 coordinator_pk_x; // coordinator's ECDH public key (x)
        uint256 coordinator_pk_y; // coordinator's ECDH public key (y)
    }

    /// @notice Result published by coordinator after time lock
    /// @dev Includes ZK correctness proof — verifiable by anyone on-chain
    struct PollResult {
        uint256 poll_id;

        /// @dev VWU-weighted vote totals (scaled ×100 to match VWUEngine).
        ///      These are sums, not counts: one participant moves a sum by
        ///      their own weight. What a run of exact sums over a known roster
        ///      yields is set out once, at SessionResult in IBeTrueCore.sol, and
        ///      holds here unchanged. Audit lens B4.
        uint256 weight_option_a;
        uint256 weight_option_b;

        /// @dev Total number of participants whose final choice was counted.
        ///      This figure is published — in PollFinalized and in the archive.
        ///      What it equals, restated after lens B8: those who chose Option A
        ///      or Option B. Silence is now a recorded state of its own —
        ///      Choice.SILENT in IBeTrueCore.sol, replacing the former NONE,
        ///      which meant "has not chosen yet" and published no data as if it
        ///      were data. So this figure is turnout, and the roster is turnout
        ///      plus those who stayed silent. At L2 both are published in full:
        ///      SessionResult in IBeTrueCore.sol carries a count and a sum of
        ///      weight for Option A, for Option B and for silence — the three
        ///      rows the Panorama shows beneath the roster total it carries at
        ///      its head, which is their sum and is stored nowhere. This figure
        ///      is the L1 counterpart of the first two of those counts added
        ///      together, and the two layers are not compared by any function.
        ///      Lens B4 adds what it yields beside its neighbours: the number of
        ///      ParticipantJoined events for the same poll is the number who
        ///      entered, and the difference between that and this figure is the
        ///      number who entered and left no counted choice. Neither event
        ///      publishes that difference; subtraction does. That difference is
        ///      not the same quantity as the silence published at L2: this one
        ///      counts those who entered the poll and did not complete a choice,
        ///      while L2 counts silence against the fixed set. See
        ///      docs/AUTHORITY_CHAIN.md, §11 and §14.
        uint256 participant_count;

        /// @dev Commitment to the full tally. REQUIRED: blinded.
        ///
        ///      Compute it as the hash of the counted choices together with a
        ///      random blinding value drawn per poll. The blinding value is
        ///      never published: the coordinator retains it and reveals it only
        ///      if the tally is disputed, at which point the commitment is
        ///      recomputed and must match. Nothing is added to this struct —
        ///      what crosses on-chain is the same single hash.
        ///
        ///      Why it is required. A hash binds, but it hides only what cannot
        ///      be guessed, and what is committed to here is small: with the
        ///      roster known and the two weight sums above published, the
        ///      candidate assignments of choices to participants are few enough
        ///      to enumerate in a small community. Hashing each candidate and
        ///      comparing would then confirm which one is right. Unblinded, the
        ///      commitment stops being a seal and becomes an oracle. Blinding
        ///      removes that use and weakens the binding not at all.
        ///
        ///      Where it is enforced: nowhere on-chain. The contract cannot tell
        ///      a blinded hash from an unblinded one, so this is an obligation
        ///      on the implementation, checkable only at the moment of dispute.
        ///      It is stated here because this is where an implementer reads
        ///      what the field is. Audit lens B4.
        bytes32 tally_commitment;

        /// @dev Groth16 ZK proof that the tally is correct
        ///      Verified on-chain by Verifier.sol
        ///      Coordinator can deny service but cannot falsify results
        bytes   zk_tally_proof;
    }

    // ══════════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Emitted when a new poll is opened
    event PollOpened(
        uint256 indexed poll_id,
        bytes32 indexed dilemma_hash,
        uint256 start_time,
        uint256 end_time
    );

    /// @notice Emitted when a participant joins a poll (ZK identity verified)
    /// @dev ERC-8281 L1 hook: this event is the observation envelope entry point.
    ///      The identity commitment is not emitted, and the nullifier is bound
    ///      to one poll, so nullifiers do not link a person across sessions.
    ///      What this event does not hide is the sending address: the join
    ///      transaction carries it, and one wallet reused across sessions links
    ///      those nullifiers after all. Submitting through a third-party relayer
    ///      does not close that link — under ERC-4337 the submitted object
    ///      carries the originating account in its `sender` field, so the
    ///      identifier moves to the account and persists across sessions. No
    ///      primitive closing it is established here, and no change to this
    ///      event closes it either. Note also what the nullifier is: a pseudonym
    ///      that distinguishes one participant within one poll, and under EU
    ///      data protection law a pseudonym is an identifier, not the absence
    ///      of one. It is indexed, and it reaches the permanent archive.
    ///      Indexed by poll, these events are also collected by one query,
    ///      and their number is the count of entrants — read beside
    ///      participant_count in PollFinalized; see the note there.
    ///      Audit lens B4.
    event ParticipantJoined(
        uint256 indexed poll_id,
        bytes32 indexed nullifier,    // session-specific, from NINIdentityProof
        uint256 timestamp
    );

    /// @notice Emitted for each encrypted message (vote or key rotation)
    /// @dev Choice is NOT emitted — stored in encrypted_data only.
    ///      This event is the coordinator's input for off-chain processing.
    ///      Receipt-freeness: all messages are equally plausible to observers.
    event MessagePublished(
        uint256 indexed poll_id,
        uint256         message_index,
        bytes           encrypted_data,
        uint256[2]      ephemeral_pk,
        uint256         timestamp
        // No participant identifier is included. That is not anonymity: the
        // message arrives in a transaction sent from the participant's own
        // address, and message_index together with timestamp gives the order
        // and the rhythm of one person's messages to anyone reading the chain.
        // A third-party relayer does not close this: under ERC-4337 the
        // submitted object carries the originating account in its `sender`
        // field, so the identifier moves to the account and persists across
        // sessions. No primitive closing it is established here, and the event
        // cannot close it either.
    );

    /// @notice Emitted when the poll is finalized with ZK correctness proof
    event PollFinalized(
        uint256 indexed poll_id,
        uint256         weight_option_a,
        uint256         weight_option_b,
        uint256         participant_count,
        bytes32         tally_commitment
    );

    // ══════════════════════════════════════════════════════════════════════
    // COORDINATOR FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Open a new poll for a binary dilemma
    /// @dev Called by the coordinator. In the design that is a threshold quorum
    ///      on the Lit Protocol network, no person and no single key holder —
    ///      and that is the second trial, not today. Poll.sol lists the Lit
    ///      Protocol MPC coordinator key among the parts not implemented, so at
    ///      the first trial the role is one address, held by a human operator as
    ///      scaffolding. An interface is not to describe the later arrangement
    ///      as the present one. What the quorum is, what it costs us, and why
    ///      the requirements table marks it an external dependency: see the
    ///      note at the coordinator field in Poll.sol.
    ///      Deploys the poll with a fixed time window.
    /// @param config Full poll configuration including coordinator public key
    /// @return poll_id Unique identifier for this poll
    function openPoll(PollConfig calldata config)
        external
        returns (uint256 poll_id);

    /// @notice Finalize a poll after the time lock
    /// @dev Called by the coordinator after processing all messages off-chain.
    ///      Publishes the result with a ZK correctness proof.
    ///      Coordinator can DENY SERVICE (withhold result) but cannot FALSIFY —
    ///      a fraudulent ZK proof is rejected by Verifier.sol.
    /// @param result Poll result including ZK tally proof
    function finalizePoll(PollResult calldata result) external;

    // ══════════════════════════════════════════════════════════════════════
    // PARTICIPANT FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Join a poll by proving ZK identity
    /// @dev Called once per nullifier per poll.
    ///      Verifies ZK proof via NINNullifierRegistry (Sybil prevention).
    ///      Multiple calls with the same nullifier are rejected.
    ///      ERC-8281 L1 attachment point: observation commitment is issued here.
    ///      Note the wording: per nullifier, not per participant. The proof
    ///      carries no sender signal, so nothing here binds the call to the
    ///      person who built it. This concerns who constructed the proof, not
    ///      who sent the call — the sending address is visible either way; see
    ///      ParticipantJoined. Consequences are set out at joinPoll in
    ///      Poll.sol; they are structural and not closed by this interface.
    /// @param poll_id         The active poll to join
    /// @param nullifier       Session-specific nullifier from NINIdentityProof circuit
    /// @param zk_proof_a      Groth16 proof element A
    /// @param zk_proof_b      Groth16 proof element B
    /// @param zk_proof_c      Groth16 proof element C
    function joinPoll(
        uint256           poll_id,
        bytes32           nullifier,
        uint256[2]    calldata zk_proof_a,
        uint256[2][2] calldata zk_proof_b,
        uint256[2]    calldata zk_proof_c
    ) external;

    /// @notice Submit an encrypted message (vote or key rotation)
    /// @dev Can be called multiple times per participant per poll, up to
    ///      max_messages — see the note there on what else that cap caps.
    ///      Each call may use a different ephemeral key (key rotation).
    ///      Only the last valid message is counted at finalization.
    ///      Choice is NOT stored in contract state — emitted as event only.
    ///      Coordinator reads events off-chain and processes after time lock.
    ///      That processing carries the obligation stated at encrypted_data: a
    ///      plaintext outside the two permitted values is discarded, and no
    ///      payload from this call reaches a language model. The contract can
    ///      enforce neither, and this is where an implementer reads them.
    ///      This is the call a coercive demand acts on, in both its forms:
    ///      "send it while I watch" and "hand me the key". Neither is closed
    ///      here — see CORE PROPERTY — RECEIPT-FREENESS above. Audit lens B6.
    /// @param poll_id Active poll ID
    /// @param message Encrypted message with ephemeral public key
    function publishMessage(
        uint256         poll_id,
        Message calldata message
    ) external;

    // ══════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Check whether a poll is currently accepting messages
    function isPollActive(uint256 poll_id) external view returns (bool);

    /// @notice Get the current state of a poll
    /// @dev Derived, not read straight off storage: a stored ACTIVE reads as
    ///      PENDING before start_time and as LOCKED after end_time. See the
    ///      note on PollState.
    function getPollState(uint256 poll_id) external view returns (PollState);

    /// @notice Get the total number of messages published in a poll
    /// @dev Used by coordinator to know when all messages are indexed.
    ///      Also a live aggregate for anyone else: read against the number of
    ///      entrants it gives the average depth of key rotation in the poll,
    ///      and read across polls it gives how that depth changes over time.
    ///      Rotation depth is the behaviour receipt-freeness rests on, so its
    ///      public average is worth naming here rather than left to be noticed.
    ///      Audit lens B4.
    function getMessageCount(uint256 poll_id) external view returns (uint256);

    /// @notice Check whether a participant has joined a poll
    /// @dev Keyed by nullifier, so no name and no address is involved. It is
    ///      still a membership check: anyone holding a nullifier learns whether
    ///      its owner took part in this poll. The nullifier is already public
    ///      in ParticipantJoined, so this getter discloses nothing the log does
    ///      not — and it removes nothing either.
    function hasJoined(
        uint256 poll_id,
        bytes32 nullifier
    ) external view returns (bool);
}