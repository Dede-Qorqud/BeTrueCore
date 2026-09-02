// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title VWUEngine
/// @notice Computes and updates Vote Weight Units (VWU) for participants
/// @dev Part of BeTrueCore Developer Package v0.2
/// @author Farman Guliyev (Safarnur) — github.com/Dede-Qorqud/BeTrueCore
///
/// Formula: VWU_new = 0.4 × A + 0.6 × Q  (with non-linear growth factor)
///
/// A = activity coefficient ∈ [0,1] — completeness of session participation
/// Q = quality coefficient ∈ {0.5, 1.0}
///     Q = 1.0 if final choice aligns with weighted majority verdict
///     Q = 0.5 if final choice diverges from weighted majority verdict
///
/// Key properties:
/// - Non-linearity of growth: diminishing returns prevent rapid farming
/// - Continuity requirement: gaps alter accumulation trajectory
/// - Sensitivity to paradoxical patterns: tracked by Sentinel agent
/// - Impossibility of instantaneous accumulation
/// - Unreachability through observation: VWU status is not a public attribute
///
/// Full formula specification (including non-linear factor) is protected
/// in the BeTrueCore master document (OpenTimestamps SHA-256).

contract VWUEngine {

    // ─────────────────────────────────────────────────────────────
    // STATE
    // ─────────────────────────────────────────────────────────────

    /// @notice VWU balance per participant (scaled ×100 for precision)
    mapping(address => uint256) public vwu;

    /// @notice Last session timestamp per participant (for continuity tracking)
    mapping(address => uint256) public lastSessionTimestamp;

    /// @notice Session count per participant
    mapping(address => uint256) public sessionCount;

    address public owner;
    address public coordinator; // Only anti-collusion coordinator can submit session results

    // ─────────────────────────────────────────────────────────────
    // STRUCTS
    // ─────────────────────────────────────────────────────────────

    /// @notice Session result submitted by coordinator after time lock
    struct SessionResult {
        address participant;
        uint8   activity_score;   // A coefficient scaled to 0–100
        bool    aligned_majority; // Q = 1.0 if true, Q = 0.5 if false
        uint256 session_timestamp;
    }

    // ─────────────────────────────────────────────────────────────
    // EVENTS
    // ─────────────────────────────────────────────────────────────

    event VWUUpdated(
        address indexed participant,
        uint256 new_vwu,
        uint256 delta,
        uint8   activity_score,
        bool    aligned_majority
    );

    event ContinuityPenalty(
        address indexed participant,
        uint256 gap_days,
        uint256 penalty_factor
    );

    // ─────────────────────────────────────────────────────────────
    // CONSTRUCTOR
    // ─────────────────────────────────────────────────────────────

    constructor(address _coordinator) {
        owner       = msg.sender;
        coordinator = _coordinator;
    }

    modifier onlyCoordinator() {
        require(msg.sender == coordinator, "Only anti-collusion coordinator");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // ─────────────────────────────────────────────────────────────
    // CORE FUNCTION
    // ─────────────────────────────────────────────────────────────

    /// @notice Update VWU after a session (called by anti-collusion coordinator)
    /// @param result Session result from coordinator after time lock
    function updateVWU(SessionResult memory result) external onlyCoordinator {
        address p = result.participant;

        // ── Step 1: Base VWU delta
        // VWU_new = 0.4 × A + 0.6 × Q
        uint256 A = uint256(result.activity_score); // 0–100
        uint256 Q = result.aligned_majority ? 100 : 50; // 100 = 1.0, 50 = 0.5

        // Base delta (scaled ×100): (0.4×A + 0.6×Q) × 100
        uint256 base_delta = (40 * A + 60 * Q) / 100;

        // ── Step 2: Non-linear growth factor
        // Diminishing returns: each additional unit requires more genuine participation
        // factor = 10000 / (100 + current_vwu/100)
        // This produces a plateau effect that prevents rapid VWU farming
        uint256 current = vwu[p];
        uint256 growth_factor = 10000 * 100 / (100 * 100 + current);
        uint256 delta = base_delta * growth_factor / 10000;

        // ── Step 3: Continuity adjustment
        // Prolonged gaps alter accumulation trajectory
        if (lastSessionTimestamp[p] > 0) {
            uint256 gap_days = (result.session_timestamp - lastSessionTimestamp[p]) / 86400;

            if (gap_days > 30) {
                // Gap > 30 days: apply continuity penalty
                // penalty_factor reduces to minimum 50% at 180+ day gap
                uint256 penalty_factor = gap_days > 180
                    ? 50
                    : 100 - ((gap_days - 30) * 50 / 150);

                delta = delta * penalty_factor / 100;

                emit ContinuityPenalty(p, gap_days, penalty_factor);
            }
        }

        // ── Step 4: Apply delta
        vwu[p] += delta;
        lastSessionTimestamp[p] = result.session_timestamp;
        sessionCount[p]++;

        emit VWUUpdated(p, vwu[p], delta, result.activity_score, result.aligned_majority);
    }

    // ─────────────────────────────────────────────────────────────
    // VIEW FUNCTIONS
    // ─────────────────────────────────────────────────────────────

    /// @notice Get VWU balance (scaled ×100)
    function getVWU(address participant) external view returns (uint256) {
        return vwu[participant];
    }

    /// @notice Get VWU as decimal string (e.g. 850 → "8.50")
    function getVWUFormatted(address participant) external view returns (uint256 integer, uint256 decimal) {
        uint256 v = vwu[participant];
        integer = v / 100;
        decimal = v % 100;
    }

    /// @notice Preview VWU delta without writing (for off-chain simulation)
    function previewDelta(
        address participant,
        uint8   activity_score,
        bool    aligned_majority
    ) external view returns (uint256 delta) {
        uint256 A = uint256(activity_score);
        uint256 Q = aligned_majority ? 100 : 50;
        uint256 base_delta = (40 * A + 60 * Q) / 100;
        uint256 current = vwu[participant];
        uint256 growth_factor = 10000 * 100 / (100 * 100 + current);
        delta = base_delta * growth_factor / 10000;
    }

    // ─────────────────────────────────────────────────────────────
    // ADMIN
    // ─────────────────────────────────────────────────────────────

    function setCoordinator(address _coordinator) external onlyOwner {
        coordinator = _coordinator;
    }
}
