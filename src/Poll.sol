// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IBeTrueCoreAntiCollusion.sol";

/*
 * ═════════════════════════════════════════════════════════════════════════════
 * BeTrueCore — Poll.sol
 * Implementation: Anti-Collusion Poll Contract (L1 stub)
 *
 * Author:  Farman Guliyev (Safarnur)
 * ORCID:   0009-0004-4841-594X
 * GitHub:  github.com/Dede-Qorqud/BeTrueCore
 * Version: 0.1 — MVP Stub
 * ═════════════════════════════════════════════════════════════════════════════
 *
 * STUB NOTICE
 * ───────────
 * This is a functional stub for MVP and testnet deployment.
 * It implements the full interface contract (IBeTrueCoreAntiCollusion)
 * and enforces all critical invariants:
 *   - ZK identity verification via NINNullifierRegistry
 *   - Time lock enforcement
  *   - Receipt-freeness of message CONTENT (choice not stored on-chain) —
 *     for the limit of this property see RECEIPT-FREENESS GUARANTEE — AND
 *     ITS LIMIT below
 *   - Key rotation (multiple messages per participant allowed, up to
 *     max_messages)
 *   - Coordinator-only finalization
 *
 * What is NOT yet implemented (Phase 2):
 *   - Full MACI message tree (Merkle accumulator of messages)
 *   - On-chain ZK tally proof verification via Verifier.sol
 *   - Lit Protocol MPC coordinator key integration
 *   - ERC-8281 observation commitment calls
 *
 * ARCHITECTURE POSITION
 * ─────────────────────
 *
 *   NINIdentityProof.circom
 *           ↓
 *   NINNullifierRegistry.verifyAndRegister()   ← called in joinPoll()
 *           ↓
 *   Poll.publishMessage()                      ← encrypted choice (event only)
 *           ↓ [time lock]
 *   Coordinator decrypts off-chain
 *   Coordinator tallies with VWU weights
 *   Coordinator generates ZK tally proof
 *           ↓
 *   Poll.finalizePoll()                          ← result + proof on-chain
 *           ↓
 *   BeTrueCoreCore.finalizeSession()             ← collective decision recorded
 *           ↓
 *   BeTrueCoreCore.applySessionParticipation()   ← per-participant contribution
 *           ↓
 *   VWUEngine.updateVWU()
 *
 * ERC-8281 INTEGRATION (Damon Zwicker, OCP) — PHASE 2
 * ─────────────────────────────────────────────────────
 * Two integration points are marked with TODO(ERC-8281):
 *
 *   1. In joinPoll(): L1 observation envelope
 *      When a participant joins, ERC-8281 issues an independently verifiable
 *      commitment to the fact that this nullifier entered this poll.
 *      Does not access private data.
 *
 *   2. In finalizePoll(): L3 two-point time-lock commitment
 *      ERC-8281 records the before/after commitment pair surrounding
 *      the Lit Protocol time-lock reveal. External verifiers can confirm
 *      the time-lock was honored without trusting BeTrueCore infrastructure.
 *
 * RECEIPT-FREENESS GUARANTEE — AND ITS LIMIT
 * ──────────────────────────────────────────
 * Encrypted messages are emitted as events — never stored in contract state.
 * The coordinator reads events off-chain. The guarantee covers the content
 * of a message: an observer cannot tell what choice it encodes, nor whether
 * it is the final one or an intermediate key rotation.
 *
 * It does not cover the sender. Every call here arrives from the
 * participant's own address — visible on the peer-to-peer network before
 * any block holds it, and kept in the chain's history afterwards. Since
 * the stage-A fix, this contract reads that address itself: joinedFrom and
 * messagesFrom are keyed by it. So an observer sees how many messages a
 * given person published and when, which is what a coercer needs; the
 * content stays hidden, the act of rotating does not.
 *
 * Removing the sender from view means relaying the calls — see the note on
 * joinedFrom at publishMessage for why that cannot be done while the join
 * check is keyed by address. AUTHORITY_CHAIN.md §11, audit lens B5.
 *
 * Nor does it cover a coercer who holds the message key. Rotation answers
 * "show me what you chose"; it does not answer "hand me the key", because
 * the holder of the key sends the last message himself and rotation then
 * works for him as it would for the participant. Closing that needs a fake
 * key indistinguishable from a real one, and no such primitive is
 * established here. The guarantee is therefore narrower than resistance to
 * coercion: a defector is not identified, inside the protocol perimeter,
 * provided each participant chooses once and with their own key. Stated in
 * full at CORE PROPERTY — RECEIPT-FREENESS in IBeTrueCoreAntiCollusion.sol.
 * Audit lens B6.
 * ═════════════════════════════════════════════════════════════════════════════
 */

/// @notice Minimal interface for NINNullifierRegistry
/// @dev Only the functions Poll.sol needs
interface ININNullifierRegistry {
    function verifyAndRegister(
        uint256           sessionId,
        bytes32           nullifier,
        uint256[2]    calldata zkProof_a,
        uint256[2][2] calldata zkProof_b,
        uint256[2]    calldata zkProof_c
    ) external returns (bool);

    function isNullifierUsed(
        uint256 sessionId,
        bytes32 nullifier
    ) external view returns (bool);
}

/// @title Poll
/// @notice BeTrueCore anti-collusion poll contract — L1 MVP stub
/// @dev Implements IBeTrueCoreAntiCollusion
contract Poll is IBeTrueCoreAntiCollusion {

    // ══════════════════════════════════════════════════════════════════════
    // STATE
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Connected ZK identity registry
    ININNullifierRegistry public immutable nullifierRegistry;

    /// @notice Anti-collusion coordinator address
    /// @dev In production this is not a person and not a single key holder:
    ///      it is a threshold quorum on the Lit Protocol network. Verified
    ///      against Lit's own documentation on 16.10.2026:
    ///        - the key is produced by distributed key generation and "no one
    ///          party ever holds the entire key"; it is never exposed to any
    ///          single node or to the requesting client
    ///        - "all operations require participation from more than
    ///          two-thirds of the network"; the threshold is a network-wide
    ///          setting, not something this project configures
    ///        - the node set is Lit's own; an application cannot choose its
    ///          holders, and the rules by which a standby operator becomes
    ///          active after the genesis set are not stated in those docs
    ///      So the decryption role is held by an outside network under a
    ///      two-thirds rule. That is what removes any single holder — and it
    ///      is also why the matching row of the requirements table carries
    ///      external dependency rather than documented primitive. Liveness
    ///      follows the same dependency: if more than a third of the network
    ///      is unreachable, no session is decrypted and none is closed.
    ///
    ///      THE ROLE IS TEMPORARY — stated here once for the whole package.
    ///      The other files point at this block rather than restating it:
    ///      BeTrueCoreCore.sol (maciCoordinator), NINNullifierRegistry.sol,
    ///      VWUEngine.sol, EthicalMatrix.sol, HarmonyAgent.sol,
    ///      docs/L5_MANAGED_AGENTS.md.
    ///      The coordinator is not an office above participants. It is an
    ///      executive function that the community holds, and it is meant to
    ///      dissolve over the three trials of the pilot:
    ///        Trial 1 — a person performs the function with mathematical
    ///                  support;
    ///        Trial 2 — the mathematics becomes the operator;
    ///        Trial 3 — the community governs through the protocol itself.
    ///      Until Trial 3 the function is held by an address, so the role has
    ///      to be passable without redeploying and without anyone standing
    ///      above it. How it passes: COORDINATOR HANDOVER at the end of this
    ///      file — two steps, through the acting coordinator alone. What the
    ///      code does not establish is that the holder is the community: an
    ///      address is an address, and the correspondence is organisational.
    ///      Name it as organisational wherever the claim is made. See
    ///      docs/AUTHORITY_CHAIN.md, §14.
    address public coordinator;

    /// @notice Address that deployed this contract
    /// @dev A deployment role, not a standing office, and not the opener of
    ///      polls — openPoll is behind onlyCoordinator. It holds no power at
    ///      all in this file: it does not open polls, does not finalize them,
    ///      and since lens B8 it can no longer replace the coordinator either.
    ///      The field is kept as a record of who deployed, nothing more.
    ///      BeTrueCore has no owner over participants: the coordinator and
    ///      the operator are the community itself.
    ///      Why the power was removed (audit lens B8). setCoordinator used to
    ///      stand behind this address, so one key outside the community could
    ///      hand the decryption role to anyone, at any moment, including
    ///      during an open poll. That is a role above the coordinator, and
    ///      the same objection applies to it as to opening polls: replacing
    ///      the holder of the decryption role at L1 and replacing it at L2 are
    ///      one act and cannot stand behind two different roles.
    address public deployer;

    /// @notice Poll counter
    uint256 private pollCounter;

    /// @notice Poll configurations
    mapping(uint256 => PollConfig) private polls;

    /// @notice Poll states
    mapping(uint256 => PollState) private pollStates;

    /// @notice Poll results (set at finalization)
    mapping(uint256 => PollResult) private pollResults;

    /// @notice Message counts per poll
    mapping(uint256 => uint256) private messageCounts;

    /// @notice Addresses that joined each poll
    /// @dev joinPoll is sent from the participant's own address, so recording
    ///      it discloses nothing the transaction did not already show. It is
    ///      what lets publishMessage reject a stranger without naming a
    ///      nullifier — naming one would let a coercer observe whether a
    ///      participant rotated their key after being told not to.
    mapping(uint256 => mapping(address => bool)) private joinedFrom;

    /// @notice Message counts per participant within a poll
    /// @dev The limit belongs to each participant, not to the poll as a whole.
    ///      A poll-wide limit means the first to arrive can exhaust the budget
    ///      of everyone else — key rotation would become first-come-first-served.
    mapping(uint256 => mapping(address => uint256)) private messagesFrom;

    /// @notice Participant join status: poll_id → nullifier → joined
    /// @dev Nullifier is session-specific — no link to identity
    mapping(uint256 => mapping(bytes32 => bool)) private joined;

    /// @notice Join counts per poll
    /// @dev Not public. The count rises by one per joinPoll transaction, and
    ///      that transaction carries the participant's address: a public
    ///      counter hands an observer the join order of a poll, address by
    ///      address. The coordinator reads it; the crowd does not.
    mapping(uint256 => uint256) private joinCounts;

    /// @notice Join count for a poll — coordinator only
    function getJoinCount(uint256 poll_id)
        external view onlyCoordinator returns (uint256)
    {
        return joinCounts[poll_id];
    }

    // ══════════════════════════════════════════════════════════════════════
    // ERRORS
    // ══════════════════════════════════════════════════════════════════════

    error OnlyCoordinator();
    error NotProposedCoordinator();
    error PollNotActive(uint256 poll_id);
    error PollNotLocked(uint256 poll_id);
    error PollNotFound(uint256 poll_id);
    error PollAlreadyFinalized(uint256 poll_id);
    error AlreadyJoined(uint256 poll_id, bytes32 nullifier);
    error NotJoined(uint256 poll_id);
    error MessageLimitReached(uint256 poll_id);
    error InvalidPollConfig();
    error ZKVerificationFailed();

    // ══════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ══════════════════════════════════════════════════════════════════════

    /// @param _nullifierRegistry Address of the deployed NINNullifierRegistry
    /// @param _coordinator       Anti-collusion coordinator address
    constructor(address _nullifierRegistry, address _coordinator) {
        require(_nullifierRegistry != address(0), "Registry: zero address");
        require(_coordinator       != address(0), "Coordinator: zero address");

        nullifierRegistry = ININNullifierRegistry(_nullifierRegistry);
        coordinator       = _coordinator;
        deployer          = msg.sender;
    }

    // ══════════════════════════════════════════════════════════════════════
    // MODIFIERS
    // ══════════════════════════════════════════════════════════════════════

     modifier onlyCoordinator() {
        if (msg.sender != coordinator) revert OnlyCoordinator();
        _;
    }

    /// @dev The poll accepts joins and messages only inside the declared
    ///      window [start_time, end_time). Before this fix the state was set
    ///      to ACTIVE at openPoll and only end_time was checked, so a poll
    ///      announced for later could be joined and voted in from the moment
    ///      it was opened: the config promised a window, the code held one
    ///      edge of it.
    modifier whenActive(uint256 poll_id) {
        if (pollStates[poll_id] != PollState.ACTIVE ||
            block.timestamp <  polls[poll_id].start_time ||
            block.timestamp >= polls[poll_id].end_time)
        {
            revert PollNotActive(poll_id);
        }
        _;
    }

    // ══════════════════════════════════════════════════════════════════════
    // COORDINATOR — OPEN POLL
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Open a new binary dilemma poll
    /// @dev Only coordinator can open polls.
    ///      Each poll gets a unique ID and a fixed time window.
    ///      Coordinator's public key is stored for participant encryption.
    function openPoll(PollConfig calldata config)
        external
        override
        onlyCoordinator
        returns (uint256 poll_id)
    {
        if (config.dilemma_hash == bytes32(0))    revert InvalidPollConfig();
        if (config.end_time <= block.timestamp)   revert InvalidPollConfig();
        if (config.end_time <= config.start_time) revert InvalidPollConfig();
        // A cap of zero opens a poll nobody can vote in: publishMessage
        // compares the sender's count against this value, and zero makes the
        // very first message fail. The poll looks alive — joins are accepted —
        // and is not, which is only discovered by trying to vote.
        // The coordinator's public key is not validated here, deliberately: a
        // wrong but non-zero key is indistinguishable from a right one to this
        // contract, so a zero check would catch one case out of many and
        // suggest the rest were covered.
        if (config.max_messages == 0)             revert InvalidPollConfig();

        pollCounter++;
        poll_id = pollCounter;

        polls[poll_id]      = config;
        pollStates[poll_id] = PollState.ACTIVE;

        emit PollOpened(
            poll_id,
            config.dilemma_hash,
            config.start_time,
            config.end_time
        );
    }

    // ══════════════════════════════════════════════════════════════════════
    // PARTICIPANT — JOIN POLL
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Join a poll by proving ZK identity
    /// @dev Verifies the Groth16 proof via NINNullifierRegistry.
    ///      One join per nullifier per poll (Sybil prevention).
    ///      Subsequent messages (key rotation) do not require a new proof.
    ///
    ///      Open, structural — not fixable in this file. The proof is not
    ///      bound to the sender: the circuit takes no sender signal, so the
    ///      arguments of this call are a bearer token. They travel across
    ///      the network in the open before reaching a block, and whoever
    ///      copies them can send them first from their own address: the
    ///      nullifier is spent, joinedFrom is set for the stranger, and the
    ///      rightful participant is turned away with AlreadyJoined.
    ///
    ///      The stranger learns neither the identity nor the choice of the
    ///      participant. But joinedFrom is the same mark publishMessage
    ///      reads, so the stolen seat carries the right to publish, up to
    ///      max_messages. One record in the session then belongs to someone
    ///      outside the community: the count of participants still agrees,
    ///      the set of them does not. Denial of entry and substitution of
    ///      signal are different failures, and this one is both.
    ///
    ///      Under lens B6 the same opening has a second use. A coercer who
    ///      demands the arguments of this call — "prove to me that you
    ///      entered" — sends them first and takes the seat, and with it the
    ///      publishing right the participant needed for re-choice. It is the
    ///      handed-over-key case one step earlier: what is handed over is the
    ///      entry proof rather than the message key. The direction chosen on
    ///      14.10.2026 closes both at once.
    ///
    ///      The OnlyPoll check added to the registry in A-13 does not help —
    ///      the call does come through this contract. Same shape as the
    ///      EthicalMatrix check bypassed one level up (A-08).
    ///
    ///      Direction chosen 14.10.2026: the ZK proof of prior join named at
    ///      publishMessage, not the sender address as a public signal of the
    ///      circuit. The proof keeps both properties at once — a stolen join
    ///      becomes worthless, because publishing requires proving knowledge
    ///      of the secret behind the nullifier, and the sender can still be
    ///      taken out of view later. Binding the circuit to the sender would
    ///      close the theft at the price of fixing the address in place for
    ///      good. Phase 2 work, not an edit to this file.
    ///
    ///      TODO(ERC-8281): After successful join, call ERC-8281 to issue
    ///      an L1 observation commitment envelope:
    ///        erc8281.commitObservation(poll_id, nullifier, block.timestamp)
    ///      This creates an independently verifiable record of entry
    ///      without exposing any private data.
    function joinPoll(
        uint256           poll_id,
        bytes32           nullifier,
        uint256[2]    calldata zk_proof_a,
        uint256[2][2] calldata zk_proof_b,
        uint256[2]    calldata zk_proof_c
    )
        external
        override
        whenActive(poll_id)
    {
        // Guard: one join per nullifier per poll
        if (joined[poll_id][nullifier]) {
            revert AlreadyJoined(poll_id, nullifier);
        }

        // Verify ZK identity proof via NINNullifierRegistry
        // Checks: Merkle membership + nullifier freshness
        // Uses poll_id as the external_nullifier (session ID in the circuit)
        bool verified = nullifierRegistry.verifyAndRegister(
            poll_id,
            nullifier,
            zk_proof_a,
            zk_proof_b,
            zk_proof_c
        );

        if (!verified) revert ZKVerificationFailed();

        // Mark as joined — key rotation messages do not need a new proof.
        // Note what this single call puts together in public: the nullifier
        // in its arguments and the sender's address in its envelope, both
        // visible before the block. The nullifier does not link a person
        // across polls, but one wallet used in several polls links its own
        // nullifiers to each other. Recording the address below adds
        // nothing to that — it is already shown by the call itself.
        joined[poll_id][nullifier] = true;
        joinedFrom[poll_id][msg.sender] = true;
        joinCounts[poll_id]++;

        emit ParticipantJoined(
            poll_id,
            nullifier,
            block.timestamp
            // identity_commitment NOT emitted — the log names no one; the
            // sender's address still does
        );
    }

    // ══════════════════════════════════════════════════════════════════════
    // PARTICIPANT — PUBLISH MESSAGE (vote or key rotation)
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Submit an encrypted message — vote or key rotation
    /// @dev Can be called multiple times by the same participant.
    ///      Each call replaces the previous choice (key rotation).
    ///      The coordinator processes all messages off-chain after the time lock
    ///      and uses only the last valid key's message.
    ///
    ///      RECEIPT-FREENESS — what it covers and what it does not:
    ///      - encrypted_data is emitted as an event, never stored in state;
    ///        it is still a public argument of this call, visible on the
    ///        network before the block and kept in the chain's history
    ///      - An observer cannot determine the choice, nor whether this is
    ///        the final message. The sender is another matter: the call
    ///        comes from the participant's own address, and the check
    ///        below reads that address
    ///      - A coercer who demands "proof" of a choice receives an
    ///        intermediate message that is cryptographically indistinguishable
    ///        from the final one. What is not hidden from that coercer is
    ///        how many messages the person published and when: message_index
    ///        and timestamp in the event, the address in the call. The
    ///        content of a rotation is protected; the fact of rotating is
    ///        not. See the limit stated in the file header.
    ///
    ///      GAS NOTE: ~50k gas per message on Optimism L2.
    ///      For 100 participants × 3 messages = 15M gas total.
    function publishMessage(
        uint256          poll_id,
        Message calldata message
    )
        external
        override
        whenActive(poll_id)
    {
        // Guard: only an address that joined this poll may publish.
        // The comment that stood here described this check; the check itself
        // was never written, so any address could publish and exhaust the
        // poll-wide message limit, locking out the people who had joined.
        // In production this becomes a ZK proof of prior join, which removes
        // the address from the picture too (see MACI_ENGINEER_PACKAGE.md).
        // Until then the two cannot both hold. This check, and the per-
        // participant limit beneath it, are keyed by the sender's address,
        // so they work only while that address is the participant's own.
        // Relay the calls and joinedFrom holds the relayer: the publishing
        // right passes to whoever goes through it, and the message budget
        // becomes one budget for all of them — the first-come-first-served
        // that this very fix removed. The proof of prior join is the only
        // path that keeps both properties at once. Audit lens B5.
        if (!joinedFrom[poll_id][msg.sender]) revert NotJoined(poll_id);

        // Anti-spam: the limit is per participant, not per poll.
        // It is counted against the sending address, and once spent it is
        // spent for good: publishing requires joinedFrom for that same
        // address, and a second joinPoll with the same nullifier is rejected,
        // so no fresh address restores the budget. A coercer who makes the
        // participant spend the cap in his presence has closed re-choice for
        // the rest of the window and keeps the choice he picked. The cap is
        // needed against spam; this is its price, and the number belongs to
        // the pilot, to be set with that price in view. Audit lens B6.
        if (messagesFrom[poll_id][msg.sender] >= polls[poll_id].max_messages) {
            revert MessageLimitReached(poll_id);
        }
        messagesFrom[poll_id][msg.sender]++;

        uint256 msg_index = messageCounts[poll_id];
        messageCounts[poll_id]++;

        // Emit message as event — NOT stored in contract state
        // Coordinator reads events off-chain after time lock
        // Choice remains hidden until coordinator decrypts
        emit MessagePublished(
            poll_id,
            msg_index,
            message.encrypted_data,
            message.ephemeral_pk,
            block.timestamp
            // Participant identity NOT emitted — see the limit stated in the
            // file header
        );
    }

    // ══════════════════════════════════════════════════════════════════════
    // COORDINATOR — FINALIZE POLL
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Finalize poll after time lock with ZK correctness proof
    /// @dev Called by coordinator after:
    ///   1. Reading all MessagePublished events
    ///   2. Decrypting messages with coordinator key
    ///   3. Applying key rotation (keeping last valid message per participant)
    ///   4. Tallying VWU-weighted results
    ///   5. Generating Groth16 ZK tally proof
    ///
    ///   SECURITY: Coordinator can DENY SERVICE (not finalize) but cannot
    ///   FALSIFY the result — a fraudulent ZK proof is rejected by Verifier.sol.
    ///   Attack converts integrity attack → availability attack.
    ///
    ///   TODO(ERC-8281): Before emitting PollFinalized, call ERC-8281 to issue
    ///   the L3 two-point time-lock commitment (reveal point):
    ///     erc8281.commitReveal(poll_id, result.tally_commitment, block.timestamp)
    ///   This closes the before/after envelope opened at the Lit Protocol lock.
    ///   External verifiers can confirm the time-lock was honored.
    ///
    ///   TODO(Phase 2): Verify result.zk_tally_proof on-chain via Verifier.sol
    ///   Currently accepted without on-chain ZK verification (stub limitation).
    function finalizePoll(PollResult calldata result)
        external
        override
        onlyCoordinator
    {
        uint256 poll_id = result.poll_id;

        // Guard: cannot finalize an already-finalized poll
        if (pollStates[poll_id] == PollState.FINALIZED) {
            revert PollAlreadyFinalized(poll_id);
        }

        // Guard: the poll has to have been opened. Storage holds ACTIVE or
        // FINALIZED and nothing else, so PENDING here means no openPoll ever
        // ran for this id. Without this check an unknown id reads end_time as
        // zero, the time lock below passes at once, and the coordinator can
        // publish a result for a poll that never existed — weights, a
        // participant count and a tally commitment, emitted and archived like
        // any other. BeTrueCoreCore.finalizeSession has the same guard as a
        // modifier; this file had none. Audit lens B8.
        if (pollStates[poll_id] != PollState.ACTIVE) {
            revert PollNotFound(poll_id);
        }

        // Guard: time lock must have been reached
        if (block.timestamp < polls[poll_id].end_time) {
            revert PollNotLocked(poll_id);
        }

        // TODO(Phase 2): Verify ZK tally proof on-chain
        // require(verifier.verifyTallyProof(result.zk_tally_proof, ...), "Invalid tally proof");

        // Store result and advance state
        pollResults[poll_id] = result;
        pollStates[poll_id]  = PollState.FINALIZED;

        emit PollFinalized(
            poll_id,
            result.weight_option_a,
            result.weight_option_b,
            result.participant_count,
            result.tally_commitment
        );
    }

    // ══════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Check whether a poll is currently accepting messages
    /// @dev Must agree with whenActive: both edges of the window, not one.
    function isPollActive(uint256 poll_id)
        external view override
        returns (bool)
    {
        return pollStates[poll_id] == PollState.ACTIVE &&
               block.timestamp >= polls[poll_id].start_time &&
               block.timestamp <  polls[poll_id].end_time;
    }

    /// @notice Get the current state of a poll
    /// @dev Both edges of the declared window are derived here, so this answer
    ///      agrees with whenActive and isPollActive. Storage only ever holds
    ///      ACTIVE or FINALIZED.
    function getPollState(uint256 poll_id)
        external view override
        returns (PollState)
    {
        if (pollStates[poll_id] == PollState.ACTIVE) {
            // Opened, but the declared window has not started yet
            if (block.timestamp < polls[poll_id].start_time) {
                return PollState.PENDING;
            }
            // Window closed — effectively locked, awaiting finalization
            if (block.timestamp >= polls[poll_id].end_time) {
                return PollState.LOCKED;
            }
        }
        return pollStates[poll_id];
    }

    /// @notice Get total messages published in a poll
    function getMessageCount(uint256 poll_id)
        external view override
        returns (uint256)
    {
        return messageCounts[poll_id];
    }

    /// @notice Check whether a nullifier has already joined this poll
    function hasJoined(uint256 poll_id, bytes32 nullifier)
        external view override
        returns (bool)
    {
        return joined[poll_id][nullifier];
    }

    /// @notice Get poll result (only after finalization)
    function getPollResult(uint256 poll_id)
        external view
        returns (PollResult memory)
    {
        require(
            pollStates[poll_id] == PollState.FINALIZED,
            "Poll not finalized"
        );
        return pollResults[poll_id];
    }

    /// @notice Get poll configuration
    function getPollConfig(uint256 poll_id)
        external view
        returns (PollConfig memory)
    {
        return polls[poll_id];
    }

    // ══════════════════════════════════════════════════════════════════════
    // COORDINATOR HANDOVER
    //
    // Two steps on purpose, and the same shape as in the other four files: the
    // acting coordinator names a successor, and the successor takes the role
    // by its own call, which is how it shows it holds the key. A one-step
    // setter would hand the decryption role to a mistyped address with no way
    // back. Naming a different address replaces an unaccepted proposal; there
    // is no separate cancel.
    //
    // The cost, stated rather than hidden: if the coordinator's key is lost,
    // nothing in this file moves the role, and reaching it means redeploying
    // this contract. No address outside the role is given a way round that,
    // because such a way is itself the capture surface this lens looks for.
    //
    // A handover during an open poll. Nothing here blocks one, and finalizePoll
    // checks the current holder only, so a poll opened by the previous
    // coordinator is closable by the successor — a poll must not become
    // unclosable because the role moved. What the code cannot ensure is that
    // the successor can decrypt it: the decryption key belongs to a threshold
    // quorum on an outside network, and matching that quorum to the new
    // address is organisational, not a property of this contract. Both events
    // carry pollCounter, so the archive shows where in the run of polls the
    // role changed hands. Power stays with the role; what is removed is the
    // silence. Audit lenses B5 and B8; see docs/AUTHORITY_CHAIN.md, §14.
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Address named to take over the coordinator role, not yet in force
    address public pendingCoordinator;

    /// @notice The acting coordinator named a successor. Nothing has moved yet.
    event CoordinatorHandoverProposed(
        address indexed proposed,
        uint256 poll_counter
    );

    /// @notice The role passed. poll_counter fixes where in the run of polls
    ///         it happened; it is not a poll id.
    event CoordinatorTransferred(
        address indexed previous,
        address indexed current,
        uint256 poll_counter
    );

    /// @notice Name the address that may take over the coordinator role
    function proposeCoordinator(address proposed) external onlyCoordinator {
        require(proposed != address(0), "Zero address");
        require(proposed != coordinator, "Already coordinator");

        pendingCoordinator = proposed;
        emit CoordinatorHandoverProposed(proposed, pollCounter);
    }

    /// @notice Take over the coordinator role, called by the named address
    function acceptCoordinator() external {
        if (msg.sender != pendingCoordinator) revert NotProposedCoordinator();

        address previous   = coordinator;
        coordinator        = msg.sender;
        pendingCoordinator = address(0);

        emit CoordinatorTransferred(previous, msg.sender, pollCounter);
    }
}