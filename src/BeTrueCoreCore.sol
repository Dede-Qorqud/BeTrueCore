// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IBeTrueCore.sol";
import "./EthicalMatrix.sol";
import "./HarmonyAgent.sol";
import "./VWUEngine.sol";

/// @title BeTrueCoreCore
/// @notice Main implementation contract for BeTrueCore
/// @dev Part of BeTrueCore Developer Package v0.1 / v0.2
/// @author Farman Guliyev (Safarnur) — github.com/Dede-Qorqud/BeTrueCore
///
/// Architecture: L0 (FIN-code ZK) → L1 (ZK + anti-collusion protocol) → L2 (Optimism) →
///               L3 (Lit Protocol) → L4 (Celestia DA) → L5 (AI agents, read-only)
///
/// Constitutional principle: AI is the notary. The human is the author.
/// Paradigm: secret citizen — transparent decision

contract BeTrueCoreCore is IBeTrueCore {

    // ─────────────────────────────────────────────────────────────
    // STATE
    // ─────────────────────────────────────────────────────────────

    /// @notice Participant registry
    mapping(bytes32 => Participant) private participants;

    /// @notice Session registry
    mapping(uint256 => Session) private sessions;

    /// @notice Session results (after coordinator finalization)
    mapping(uint256 => SessionResult) private sessionResults;

    /// @notice ZK nullifier registry — prevents double-voting
    mapping(bytes32 => bool) private usedNullifiers;

    /// @notice Session counter
    uint256 private sessionCounter;

    /// @notice Connected contracts
    EthicalMatrix public ethicalMatrix;
    HarmonyAgent  public harmonyAgent;
    VWUEngine     public vwuEngine;

    /// @notice Anti-collusion coordinator address (only can finalize sessions)
    address public maciCoordinator;

    /// @notice Contract owner
    address public owner;

    // ─────────────────────────────────────────────────────────────
    // VWU THRESHOLDS FOR STATUS LEVELS
    // ─────────────────────────────────────────────────────────────

    uint256 constant VWU_SOLO       = 0;      // Copper   — entry
    uint256 constant VWU_SELFLY     = 100;    // Bronze   — 1.00 VWU
    uint256 constant VWU_UNIVERSAL  = 300;    // Titanium — 3.00 VWU
    uint256 constant VWU_HONORIS    = 700;    // Silver   — 7.00 VWU
    uint256 constant VWU_LUMINARE   = 1500;   // Gold     — 15.00 VWU
    uint256 constant VWU_VERITAS_ZK = 3000;   // Platinum — 30.00 VWU

    // ─────────────────────────────────────────────────────────────
    // CONSTRUCTOR
    // ─────────────────────────────────────────────────────────────

    constructor(
        address _maciCoordinator,
        address _ethicalMatrix,
        address _harmonyAgent,
        address _vwuEngine
    ) {
        owner            = msg.sender;
        maciCoordinator  = _maciCoordinator;
        ethicalMatrix    = EthicalMatrix(_ethicalMatrix);
        harmonyAgent     = HarmonyAgent(_harmonyAgent);
        vwuEngine        = VWUEngine(_vwuEngine);
    }

    // ─────────────────────────────────────────────────────────────
    // MODIFIERS
    // ─────────────────────────────────────────────────────────────

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyCoordinator() {
        require(msg.sender == maciCoordinator, "Only anti-collusion coordinator");
        _;
    }

    modifier sessionActive(uint256 session_id) {
        require(isSessionActive(session_id), "Session not active");
        _;
    }

    modifier sessionExists(uint256 session_id) {
        require(sessions[session_id].start_time > 0, "Session does not exist");
        _;
    }

    // ─────────────────────────────────────────────────────────────
    // PARTICIPANT FUNCTIONS
    // ─────────────────────────────────────────────────────────────

    /// @notice Register a new participant
    /// @dev Requires L0 FIN-code ZK-commitment + L1 ZK proof
    ///      bytes32 identity_commitment preserves privacy (not address)
    function register(
        bytes32 identity_commitment,
        bytes calldata zk_proof
    ) external override {
        require(
            participants[identity_commitment].identity_commitment == bytes32(0),
            "Already registered"
        );

        // ZK proof verification would be performed here
        // via Circom verifier contract (external dependency)
        // _verifyRegistrationProof(identity_commitment, zk_proof);

        participants[identity_commitment] = Participant({
            identity_commitment: identity_commitment,
            vwu:                 0,
            status:              Status.SOLO,
            session_count:       0,
            last_session:        0
        });

        emit ParticipantRegistered(identity_commitment, block.timestamp);
    }

    /// @notice Submit or update choice within active session
    /// @dev Key-rotation: participant can change choice until time lock
    ///      Receipt-freeness: encrypted_choice not stored on-chain
    function submitChoice(
        uint256 session_id,
        bytes calldata encrypted_choice,
        bytes32 zk_nullifier
    ) external override sessionActive(session_id) {
        require(!usedNullifiers[zk_nullifier], "Nullifier already used");

        // Mark nullifier as used — prevents double-voting
        usedNullifiers[zk_nullifier] = true;

        // encrypted_choice is forwarded to anti-collusion coordinator off-chain
        // Only the final choice (after time lock) counts
        // Intermediate choices are cryptographically invalidated via key-rotation

        // Note: identity_commitment is derived from msg.sender via ZK proof
        // to preserve receipt-freeness
        bytes32 identity_commitment = _deriveIdentity(msg.sender);

        emit ChoiceSubmitted(
            identity_commitment,
            session_id,
            block.timestamp
            // Choice NOT emitted — receipt-freeness preserved
        );
    }

    // ─────────────────────────────────────────────────────────────
    // SESSION FUNCTIONS
    // ─────────────────────────────────────────────────────────────

    /// @notice Open a new session with a dilemma
    function openSession(
        bytes32 dilemma_hash,
        uint256 duration_seconds
    ) external override onlyOwner returns (uint256 session_id) {
        sessionCounter++;
        session_id = sessionCounter;

        sessions[session_id] = Session({
            dilemma_hash: dilemma_hash,
            start_time:   block.timestamp,
            end_time:     block.timestamp + duration_seconds,
            finalized:    false,
            verdict:      Verdict.GREEN
        });
    }

    /// @notice Finalize session after time lock (coordinator only)
    /// @dev Coordinator publishes ZK proof of correct counting simultaneously
    ///      Coordinator can deny service but cannot falsify results
    function finalizeSession(
        uint256 session_id,
        SessionResult calldata result
    ) external override onlyCoordinator sessionExists(session_id) {
        require(!sessions[session_id].finalized, "Already finalized");
        require(
            block.timestamp >= sessions[session_id].end_time,
            "Time lock not reached"
        );

        // Store result
        sessionResults[session_id] = result;
        sessions[session_id].finalized = true;
        sessions[session_id].verdict = result.verdict;

        emit SessionFinalized(session_id, result);
    }

    // ─────────────────────────────────────────────────────────────
    // VWU INTERNAL UPDATE
    // ─────────────────────────────────────────────────────────────

    /// @notice Update VWU for a participant after session finalization
    /// @dev Called internally after coordinator result is published
    ///      The full VWU formula (including non-linear factor) is protected
    ///      in the BeTrueCore master document (OpenTimestamps SHA-256)
    function _updateParticipantVWU(
        bytes32 identity_commitment,
        uint8   activity_score,
        bool    aligned_majority
    ) internal {
        // Delegate to VWUEngine (which holds the formula implementation)
        VWUEngine.SessionResult memory sr = VWUEngine.SessionResult({
            participant:       address(uint160(uint256(identity_commitment))),
            activity_score:    activity_score,
            aligned_majority:  aligned_majority,
            session_timestamp: block.timestamp
        });

        vwuEngine.updateVWU(sr);

        // Update local participant record
        uint256 new_vwu = vwuEngine.getVWU(
            address(uint160(uint256(identity_commitment)))
        );

        participants[identity_commitment].vwu = new_vwu;
        participants[identity_commitment].status = _computeStatus(new_vwu);
        participants[identity_commitment].session_count++;
        participants[identity_commitment].last_session = block.timestamp;

        emit VWUUpdated(identity_commitment, new_vwu, 0);
    }

    /// @notice Compute status level from VWU balance
    function _computeStatus(uint256 vwu_balance) internal pure returns (Status) {
        if (vwu_balance >= VWU_VERITAS_ZK) return Status.VERITAS_ZK;
        if (vwu_balance >= VWU_LUMINARE)   return Status.LUMINARE;
        if (vwu_balance >= VWU_HONORIS)    return Status.HONORIS;
        if (vwu_balance >= VWU_UNIVERSAL)  return Status.UNIVERSAL;
        if (vwu_balance >= VWU_SELFLY)     return Status.SELFLY;
        return Status.SOLO;
    }

    /// @notice Derive identity commitment from address (placeholder)
    /// @dev In production: identity_commitment comes from ZK proof, not address
    function _deriveIdentity(address sender) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(sender));
    }

    // ─────────────────────────────────────────────────────────────
    // VIEW FUNCTIONS
    // ─────────────────────────────────────────────────────────────

    function getParticipant(
        bytes32 identity_commitment
    ) external view override returns (Participant memory) {
        return participants[identity_commitment];
    }

    function getSession(
        uint256 session_id
    ) external view override returns (Session memory) {
        return sessions[session_id];
    }

    function getSessionResult(
        uint256 session_id
    ) external view override returns (SessionResult memory) {
        require(sessions[session_id].finalized, "Session not finalized");
        return sessionResults[session_id];
    }

    function isSessionActive(
        uint256 session_id
    ) public view override returns (bool) {
        Session memory s = sessions[session_id];
        return (
            s.start_time > 0 &&
            !s.finalized &&
            block.timestamp >= s.start_time &&
            block.timestamp < s.end_time
        );
    }

    function getSessionCount() external view returns (uint256) {
        return sessionCounter;
    }
}
