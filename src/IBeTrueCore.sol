// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title IBeTrueCore
/// @notice Core interface for BeTrueCore — cryptographic infrastructure for
///         sovereign collective decision-making
/// @dev Part of BeTrueCore Developer Package v0.1 / v0.2
/// @author Farman Guliyev (Safarnur) — github.com/Dede-Qorqud/BeTrueCore
///
/// Constitutional principle: AI is the notary. The human is the author.
/// Paradigm: secret citizen — transparent decision

interface IBeTrueCore {

    // ─────────────────────────────────────────────────────────────
    // ENUMS
    // ─────────────────────────────────────────────────────────────

    /// @notice Participant status levels (VWU-based progression)
    enum Status {
        SOLO,       // Copper  — entry level
        SELFLY,     // Bronze  — individual signal established
        UNIVERSAL,  // Titanium — consistent participation
        HONORIS,    // Silver  — high quality judgment
        LUMINARE,   // Gold    — community anchor
        VERITAS_ZK  // Platinum — zero-knowledge verified leader
    }

    /// @notice Binary choice for each dilemma (time-locked until session close)
    enum Choice {
        NONE,       // no choice yet
        OPTION_A,   // first option
        OPTION_B    // second option
    }

    /// @notice Traffic light verdict from Harmony Agent
    enum Verdict {
        RED,        // Ematch < 0.4 · integrity threshold breached
        YELLOW,     // Ematch 0.4–0.7 · partial degradation
        GREEN       // Ematch >= 0.7 · integrity confirmed
    }

    // ─────────────────────────────────────────────────────────────
    // STRUCTS
    // ─────────────────────────────────────────────────────────────

    /// @notice Participant record
    /// @dev bytes32 used for identity (not address) to preserve privacy
    struct Participant {
        bytes32 identity_commitment;  // ZK-commitment to verified state identity (FIN-code)
        uint256 vwu;                  // Vote Weight Unit (scaled ×100)
        Status  status;               // Current status level
        uint256 session_count;        // Total sessions participated
        uint256 last_session;         // Timestamp of last session
    }

    /// @notice Session (dilemma + time window)
    struct Session {
        bytes32 dilemma_hash;         // IPFS hash of the dilemma content
        uint256 start_time;           // Session open timestamp
        uint256 end_time;             // Time lock — after this, choices are final
        bool    finalized;            // Whether anti-collusion coordinator has published the result
        Verdict verdict;              // Harmony Agent verdict for this session
    }

    /// @notice Session result after coordinator finalization
    struct SessionResult {
        uint256 session_id;
        uint256 total_weight_a;       // Σ VWU of participants choosing OPTION_A
        uint256 total_weight_b;       // Σ VWU of participants choosing OPTION_B
        bytes32 zk_proof_hash;        // Hash of ZK correctness proof from coordinator
        Verdict verdict;              // Ethical verdict from Harmony Agent
    }

    // ─────────────────────────────────────────────────────────────
    // EVENTS
    // ─────────────────────────────────────────────────────────────

    /// @notice Emitted when a participant registers (L0 + L1 verified)
    event ParticipantRegistered(
        bytes32 indexed identity_commitment,
        uint256 timestamp
    );

    /// @notice Emitted when a participant submits or changes their choice
    /// @dev Key-rotation: intermediate choices are invalidated
    event ChoiceSubmitted(
        bytes32 indexed identity_commitment,
        uint256 indexed session_id,
        uint256 timestamp
        // Choice is NOT emitted — receipt-freeness preserved
    );

    /// @notice Emitted when a session is finalized by the coordinator
    event SessionFinalized(
        uint256 indexed session_id,
        SessionResult result
    );

    /// @notice Emitted when VWU is updated after a session
    event VWUUpdated(
        bytes32 indexed identity_commitment,
        uint256 new_vwu,
        uint256 delta
    );

    /// @notice Emitted when Harmony Agent issues a verdict
    event EthicalVerdictIssued(
        uint256 indexed session_id,
        Verdict verdict,
        uint256 aggregate_ematch    // 0–100
    );

    // ─────────────────────────────────────────────────────────────
    // PARTICIPANT FUNCTIONS
    // ─────────────────────────────────────────────────────────────

    /// @notice Register a new participant (requires L0 FIN-code ZK-commitment + L1 ZK proof)
    /// @param identity_commitment ZK commitment to verified state identity (FIN-code)
    /// @param zk_proof ZK-SNARK proof of valid registration
    function register(
        bytes32 identity_commitment,
        bytes calldata zk_proof
    ) external;

    /// @notice Submit or update choice for a session (until time lock)
    /// @dev Key-rotation — only final choice counts
    /// @param session_id Active session ID
    /// @param encrypted_choice Encrypted choice (receipt-free)
    /// @param zk_nullifier ZK nullifier preventing double-voting
    function submitChoice(
        uint256 session_id,
        bytes calldata encrypted_choice,
        bytes32 zk_nullifier
    ) external;

    // ─────────────────────────────────────────────────────────────
    // SESSION FUNCTIONS
    // ─────────────────────────────────────────────────────────────

    /// @notice Open a new session with a dilemma
    /// @param dilemma_hash IPFS hash of the dilemma content
    /// @param duration_seconds Session duration before time lock
    function openSession(
        bytes32 dilemma_hash,
        uint256 duration_seconds
    ) external returns (uint256 session_id);

    /// @notice Finalize a session after time lock (coordinator only)
    /// @param session_id Session to finalize
    /// @param result Aggregated result with ZK correctness proof
    function finalizeSession(
        uint256 session_id,
        SessionResult calldata result
    ) external;

    // ─────────────────────────────────────────────────────────────
    // VIEW FUNCTIONS
    // ─────────────────────────────────────────────────────────────

    /// @notice Get participant data
    function getParticipant(
        bytes32 identity_commitment
    ) external view returns (Participant memory);

    /// @notice Get session data
    function getSession(
        uint256 session_id
    ) external view returns (Session memory);

    /// @notice Get session result (after finalization)
    function getSessionResult(
        uint256 session_id
    ) external view returns (SessionResult memory);

    /// @notice Check if a session is within its time window
    function isSessionActive(
        uint256 session_id
    ) external view returns (bool);
}
