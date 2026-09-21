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
 * A participant can change their binary choice any number of times before
 * the time lock. Only the final choice counts. No intermediate choice can
 * serve as proof of a transaction — all intermediate states are equally
 * plausible. Vote buying is architecturally meaningless.
 *
 *   Choice 1 (T=0):   EncMsg(key_1, OPTION_A)
 *   Choice 2 (T=30):  EncMsg(key_2, OPTION_B)   ← key_1 invalidated
 *   Choice 3 (T=45):  EncMsg(key_3, OPTION_A)   ← key_2 invalidated
 *   TIME LOCK (T=60): only OPTION_A via key_3 counted
 *
 * ERC-8281 INTEGRATION POINT (Damon Zwicker, OCP)
 * ─────────────────────────────────────────────────
 * ERC-8281 (Observation Commitment Protocol) attaches to two points:
 *
 *   L1 attachment: the VoteProof observation envelope
 *     When a participant joins a poll, ERC-8281 wraps the moment of
 *     entry with an independently verifiable commitment — without
 *     accessing BeTrueCore's private VWU inputs or protocol semantics.
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
    enum PollState {
        ACTIVE,     // accepting messages
        LOCKED,     // time lock reached, awaiting coordinator finalization
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
        bytes   encrypted_data;

        /// @dev Participant's ephemeral public key for this message.
        ///      Key rotation: each new message may use a different ephemeral key.
        ///      Only the last valid key's message is counted.
        uint256[2] ephemeral_pk;
    }

    /// @notice Poll configuration set at opening
    struct PollConfig {
        bytes32 dilemma_hash;     // keccak256 of the dilemma text
        uint256 start_time;       // block.timestamp at opening
        uint256 end_time;         // start_time + duration
        uint256 max_messages;     // anti-spam cap (default: 25,000)
        uint256 coordinator_pk_x; // coordinator's ECDH public key (x)
        uint256 coordinator_pk_y; // coordinator's ECDH public key (y)
    }

    /// @notice Result published by coordinator after time lock
    /// @dev Includes ZK correctness proof — verifiable by anyone on-chain
    struct PollResult {
        uint256 poll_id;

        /// @dev VWU-weighted vote totals (scaled ×100 to match VWUEngine)
        uint256 weight_option_a;
        uint256 weight_option_b;

        /// @dev Total number of participants whose final choice was counted
        uint256 participant_count;

        /// @dev Commitment to the full tally (hash of all counted choices)
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
    ///      Identity commitment is NOT emitted — receipt-freeness preserved.
    event ParticipantJoined(
        uint256 indexed poll_id,
        bytes32 indexed nullifier,    // session-specific, from NINIdentityProof
        uint256 timestamp
        // identity_commitment is NOT included — anonymity preserved
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
        // Participant identity is NOT included — anonymity preserved
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
    /// @dev Called by the coordinator (Lit Protocol MPC quorum).
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
    /// @dev Called once per participant per poll.
    ///      Verifies ZK proof via NINNullifierRegistry (Sybil prevention).
    ///      Multiple calls with the same nullifier are rejected.
    ///      ERC-8281 L1 attachment point: observation commitment is issued here.
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
    /// @dev Can be called multiple times per participant per poll.
    ///      Each call may use a different ephemeral key (key rotation).
    ///      Only the last valid message is counted at finalization.
    ///      Choice is NOT stored in contract state — emitted as event only.
    ///      Coordinator reads events off-chain and processes after time lock.
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
    function getPollState(uint256 poll_id) external view returns (PollState);

    /// @notice Get the total number of messages published in a poll
    /// @dev Used by coordinator to know when all messages are indexed
    function getMessageCount(uint256 poll_id) external view returns (uint256);

    /// @notice Check whether a participant has joined a poll
    /// @dev Checks by nullifier — identity remains anonymous
    function hasJoined(
        uint256 poll_id,
        bytes32 nullifier
    ) external view returns (bool);
}
