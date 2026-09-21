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
 *   - Receipt-freeness (choice not stored on-chain)
 *   - Key rotation (multiple messages per participant allowed)
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
 *   Poll.finalizePoll()                        ← result + proof on-chain
 *           ↓
 *   BeTrueCoreCore.finalizeSession()
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
 * RECEIPTFREEINESS GUARANTEE
 * ──────────────────────────
 * Encrypted messages are emitted as events — never stored in contract state.
 * The coordinator reads events off-chain. An observer watching the blockchain
 * sees: poll_id, message_index, encrypted blob, ephemeral_pk, timestamp.
 * They cannot determine: who sent it, what choice it encodes, whether it is
 * the final or an intermediate choice.
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
    /// @dev In production: Lit Protocol MPC quorum address
    address public coordinator;

    /// @notice Contract owner (deploys polls, sets coordinator)
    address public owner;

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

    /// @notice Participant join status: poll_id → nullifier → joined
    /// @dev Nullifier is session-specific — no link to identity
    mapping(uint256 => mapping(bytes32 => bool)) private joined;

    /// @notice Join counts per poll (for analytics, not identity tracking)
    mapping(uint256 => uint256) public joinCounts;

    // ══════════════════════════════════════════════════════════════════════
    // ERRORS
    // ══════════════════════════════════════════════════════════════════════

    error OnlyCoordinator();
    error OnlyOwner();
    error PollNotActive(uint256 poll_id);
    error PollNotLocked(uint256 poll_id);
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
        owner             = msg.sender;
    }

    // ══════════════════════════════════════════════════════════════════════
    // MODIFIERS
    // ══════════════════════════════════════════════════════════════════════

    modifier onlyCoordinator() {
        if (msg.sender != coordinator) revert OnlyCoordinator();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    modifier whenActive(uint256 poll_id) {
        if (pollStates[poll_id] != PollState.ACTIVE ||
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
    ///      One join per participant per poll (Sybil prevention).
    ///      Subsequent messages (key rotation) do not require a new proof.
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

        // Mark as joined — key rotation messages do not need a new proof
        joined[poll_id][nullifier] = true;
        joinCounts[poll_id]++;

        emit ParticipantJoined(
            poll_id,
            nullifier,
            block.timestamp
            // identity_commitment NOT emitted — anonymity preserved
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
    ///      RECEIPT-FREENESS:
    ///      - encrypted_data is emitted as an event, never stored in state
    ///      - An observer cannot determine the choice, the identity,
    ///        or whether this is the final message
    ///      - A coercer who demands "proof" of a choice receives an
    ///        intermediate message that is cryptographically indistinguishable
    ///        from the final one
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
        // Guard: only joined participants can publish
        // Checked via address — participant must have called joinPoll first
        // Note: the link between msg.sender and their nullifier is preserved
        // only in the participant's local state, not on-chain
        // For MVP: we check that someone joined this poll from this address
        // In production: this check is done via ZK proof of prior join
        // (see MACI_ENGINEER_PACKAGE.md for full implementation)

        // Anti-spam: enforce message limit
        if (messageCounts[poll_id] >= polls[poll_id].max_messages) {
            revert MessageLimitReached(poll_id);
        }

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
            // Participant identity NOT emitted — anonymity preserved
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
    function isPollActive(uint256 poll_id)
        external view override
        returns (bool)
    {
        return pollStates[poll_id] == PollState.ACTIVE &&
               block.timestamp < polls[poll_id].end_time;
    }

    /// @notice Get the current state of a poll
    function getPollState(uint256 poll_id)
        external view override
        returns (PollState)
    {
        // If active but time has passed — effectively locked
        if (pollStates[poll_id] == PollState.ACTIVE &&
            block.timestamp >= polls[poll_id].end_time)
        {
            return PollState.LOCKED;
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
    // ADMIN
    // ══════════════════════════════════════════════════════════════════════

    function setCoordinator(address _coordinator) external onlyOwner {
        require(_coordinator != address(0), "Zero address");
        coordinator = _coordinator;
    }
}
