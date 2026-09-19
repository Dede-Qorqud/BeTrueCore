// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
 * ═════════════════════════════════════════════════════════════════════════════
 * BeTrueCore — VWUEngine.sol
 * Vote Weight Unit / Verified Wisdom Unit — Computation Engine
 *
 * Author:  Farman Guliyev (Safarnur)
 * ORCID:   0009-0004-4841-594X
 * GitHub:  github.com/Dede-Qorqud/BeTrueCore
 * Version: 0.4
 * ═════════════════════════════════════════════════════════════════════════════
 *
 * VWU — dual name, single measure:
 *   Vote Weight Unit     — technical dimension: the unit of voting weight
 *   Verified Wisdom Unit — substantive dimension: the unit of verified wisdom
 *
 * "Varlıq özü imzadır" — presence itself is the signature.
 * VWU measures not the fact of asset ownership but the trajectory of participation.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * OPEN FORMULA (preprint [11], DOI: 10.5281/zenodo.22179301):
 *
 *   base_delta = 0.4 × A + 0.6 × Q
 *
 *   A — activity coefficient ∈ [0,100]
 *       Reflects depth of the seven-step cycle:
 *       A = steps_completed × 100 / 7
 *       0 steps = 0, 7 steps = 100
 *
 *   Q — quality coefficient
 *       Q = 100 if final choice aligned with weighted majority verdict
 *       Q = 50  if final choice diverged from weighted majority verdict
 *
 * Full specification (non-linear factor, EMA parameters, momentum) is
 * protected in the BeTrueCore master document (OpenTimestamps SHA-256).
 * NDA required.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * KEY PROPERTIES:
 *
 *   1. Irreversibility of base score  — VWU_BASE is assigned at registration
 *                                       and cannot be reduced by any mechanism
 *   2. Bounded accumulation           — VWU cannot exceed VWU_CAP
 *                                       preprint [11]: «boundedness is not a
 *                                       technical constraint but a normative one»
 *   3. Non-linear growth              — diminishing returns; instantaneous
 *                                       accumulation is architecturally impossible
 *   4. Silence as sovereign decision  — absence does NOT reduce VWU;
 *                                       only the delta of the next session is adjusted
 *   5. Non-reproducibility            — behavioral trajectory cannot be fabricated at scale
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * CONTINUITY PENALTY (preprint [11]):
 *
 *   ≤ 30 days absent   — full delta (factor 1.0)
 *   30–180 days        — linear reduction from 1.0 to 0.5
 *   > 180 days         — maximum penalty: delta × 0.5
 *
 *   VWU balance is NOT reduced. Only the next session delta is adjusted.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * SEVEN-STEP CYCLE (preprint [12], DOI: 10.5281/zenodo.22537058):
 *
 *   Two participants with the same YES/NO answer may carry different weight
 *   depending on how many of the seven steps they completed.
 *   steps_completed: 0 = no participation, 7 = full cycle.
 *   «The dilemma remains binary — yes or no — but the seven steps measure
 *    the seriousness of the path toward that binary choice.»
 * ═════════════════════════════════════════════════════════════════════════════
 */

/// @title VWUEngine
/// @notice Computes and updates Vote Weight Unit / Verified Wisdom Unit
/// @dev Part of BeTrueCore Developer Package v0.3
/// @author Farman Guliyev (Safarnur) — github.com/Dede-Qorqud/BeTrueCore
contract VWUEngine {

    // ══════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Base score assigned at registration — «presence itself is the signature»
    /// @dev Irreversible. Preprint [11]: «this score is irreversible and non-redeemable»
    uint256 public constant VWU_BASE = 1;

    // Status thresholds
    uint256 public constant VWU_SOLO       = 0;
    uint256 public constant VWU_SELFLY     = 100;   // 1.00 VWU
    uint256 public constant VWU_UNIVERSAL  = 300;   // 3.00 VWU
    uint256 public constant VWU_HONORIS    = 700;   // 7.00 VWU
    uint256 public constant VWU_LUMINARE   = 1500;  // 15.00 VWU
    uint256 public constant VWU_VERITAS_ZK = 3000;  // 30.00 VWU

    /// @notice Upper bound on VWU accumulation — normative architectural principle
    /// @dev Value is protected in the BeTrueCore master document (NDA required).
    ///      Its existence is public; its exact value is not.
    uint256 private constant VWU_CAP = 3000; // [PROTECTED]

    /// @notice Steps in the seven-step participation cycle
    uint256 public constant CYCLE_STEPS = 7;

    // ══════════════════════════════════════════════════════════════════════
    // ENUMS
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Participant status levels based on accumulated VWU
    enum Status {
        SOLO,       // Copper   — entry level
        SELFLY,     // Bronze   — individual signal established
        UNIVERSAL,  // Titanium — consistent participation
        HONORIS,    // Silver   — high quality judgment
        LUMINARE,   // Gold     — community anchor
        VERITAS_ZK  // Platinum — ZK-verified leader
    }

    // ══════════════════════════════════════════════════════════════════════
    // STATE
    // ══════════════════════════════════════════════════════════════════════

    /// @notice VWU balance per participant
    /// @dev private — participants can only read their own balance via getMyVWU().
    ///      Preprint [11]: «VWU status is not a public attribute»
    mapping(address => uint256) private vwu;

    /// @notice Last session timestamp per participant (for continuity penalty)
    mapping(address => uint256) public lastSessionTimestamp;

    /// @notice Session count per participant
    mapping(address => uint256) public sessionCount;

    /// @notice Registration flag (distinguishes VWU=1 from unregistered)
    mapping(address => bool) public registered;

    /// @notice Count of participants at each status level
    /// @dev Public — shows how many «stars» at each level, not whose they are.
    ///      Like stars in the sky: visible count, anonymous ownership.
    mapping(Status => uint256) public statusCount;

    address public owner;
    address public coordinator;

    // ══════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Session result submitted by the anti-collusion coordinator after time lock
    struct SessionResult {
        address participant;

        /// @notice Steps completed in the seven-step cycle (0–7)
        /// @dev Preprint [12]: depth of cycle determines weight contribution
        ///      even when the final binary answer is identical to another participant's
        uint8   steps_completed;

        /// @notice Whether the final choice aligned with the weighted majority verdict
        /// @dev true → Q = 100, false → Q = 50
        bool    aligned_majority;

        uint256 session_timestamp;
    }

    // ══════════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════════

    event ParticipantInitialized(
        address indexed participant,
        uint256 base_vwu
    );

    event VWUUpdated(
        address indexed participant,
        uint256 new_vwu,
        uint256 delta,
        uint8   steps_completed,
        bool    aligned_majority
    );

    event ContinuityPenalty(
        address indexed participant,
        uint256 gap_days,
        uint256 penalty_factor
    );

    event StatusAdvanced(
        address indexed participant,
        Status  new_status,
        uint256 vwu_at_advance
    );

    // ══════════════════════════════════════════════════════════════════════
    // ERRORS
    // ══════════════════════════════════════════════════════════════════════

    error NotCoordinator();
    error NotOwner();
    error AlreadyRegistered(address participant);
    error NotRegistered(address participant);
    error InvalidStepsCompleted(uint8 steps);

    // ══════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ══════════════════════════════════════════════════════════════════════

    constructor(address _coordinator) {
        owner       = msg.sender;
        coordinator = _coordinator;
    }

    // ══════════════════════════════════════════════════════════════════════
    // MODIFIERS
    // ══════════════════════════════════════════════════════════════════════

    modifier onlyCoordinator() {
        if (msg.sender != coordinator) revert NotCoordinator();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    // ══════════════════════════════════════════════════════════════════════
    // REGISTRATION
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Initialize a participant at registration
    /// @dev Assigns VWU_BASE = 1 — the irreversible base score.
    ///      Called by coordinator after ZK identity proof is verified.
    ///      Preprint [11]: «Every verified participant receives a non-zero
    ///      base score upon registration. This score is irreversible.»
    /// @param participant Wallet address of the new participant
    function initializeParticipant(address participant)
        external
        onlyCoordinator
    {
        if (registered[participant]) revert AlreadyRegistered(participant);

        registered[participant]  = true;
        vwu[participant]         = VWU_BASE;
        statusCount[Status.SOLO]++;

        emit ParticipantInitialized(participant, VWU_BASE);
    }

    // ══════════════════════════════════════════════════════════════════════
    // CORE — UPDATE VWU
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Update VWU after a session (called by coordinator after time lock)
    /// @dev Silence is sovereign — VWU balance is never reduced by absence.
    ///      Only the delta of the next session is adjusted via continuity penalty.
    /// @param result Session result from the anti-collusion coordinator
    function updateVWU(SessionResult memory result) external onlyCoordinator {
        address p = result.participant;

        if (!registered[p])             revert NotRegistered(p);
        if (result.steps_completed > 7) revert InvalidStepsCompleted(result.steps_completed);

        Status status_before = _computeStatus(vwu[p]);

        // ── Step 1: Base delta ─────────────────────────────────────────────
        // A = steps_completed × 100 / 7  (seven-step cycle → 0..100)
        // Preprint [12]: depth of cycle determines weight
        uint256 A = uint256(result.steps_completed) * 100 / CYCLE_STEPS;
        uint256 Q = result.aligned_majority ? 100 : 50;

        // base_delta = 0.4 × A + 0.6 × Q  (open part of the formula)
        uint256 base_delta = (40 * A + 60 * Q) / 100;

        // ── Step 2: Non-linear growth factor ──────────────────────────────
        // Diminishing returns: each additional unit requires more genuine participation.
        // Instantaneous accumulation is architecturally impossible.
        // Full formula is protected. This is the public approximation.
        uint256 current       = vwu[p];
        uint256 growth_factor = 10000 * 100 / (100 * 100 + current);
        uint256 delta         = base_delta * growth_factor / 10000;

        // ── Step 3: Continuity adjustment ─────────────────────────────────
        // VWU balance is NOT reduced. Only the next session delta is adjusted.
        // Preprint [11]: «Silence is a sovereign decision, not a technical error»
        if (lastSessionTimestamp[p] > 0 &&
            result.session_timestamp > lastSessionTimestamp[p])
        {
            uint256 gap_days =
                (result.session_timestamp - lastSessionTimestamp[p]) / 1 days;

            if (gap_days > 30) {
                uint256 penalty_factor = gap_days > 180
                    ? 50
                    : 100 - ((gap_days - 30) * 50 / 150);

                delta = delta * penalty_factor / 100;
                emit ContinuityPenalty(p, gap_days, penalty_factor);
            }
        }

        // ── Step 4: Apply delta with upper bound ───────────────────────────
        // Preprint [11]: «no participant can accumulate unlimited weight»
        uint256 new_vwu = current + delta;
        if (new_vwu > VWU_CAP) new_vwu = VWU_CAP;

        vwu[p]                  = new_vwu;
        lastSessionTimestamp[p] = result.session_timestamp;
        sessionCount[p]++;

        emit VWUUpdated(p, new_vwu, delta,
                        result.steps_completed, result.aligned_majority);

        // ── Step 5: Update status distribution and emit event ──────────────
        // statusCount is public — shows how many stars at each level,
        // not whose they are.
        Status status_after = _computeStatus(new_vwu);
        if (status_after != status_before) {
            if (statusCount[status_before] > 0) {
                statusCount[status_before]--;
            }
            statusCount[status_after]++;
            emit StatusAdvanced(p, status_after, new_vwu);
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // VIEW — PERSONAL (caller sees only their own data)
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Participant reads their own current status
    /// @dev msg.sender only. No one can read another participant's status.
    ///      Preprint [11]: «VWU status is not a public attribute»
    function getMyStatus() external view returns (Status) {
        return _computeStatus(vwu[msg.sender]);
    }

    /// @notice Participant reads their own VWU balance
    function getMyVWU() external view returns (uint256) {
        return vwu[msg.sender];
    }

    /// @notice VWU as integer and decimal parts (850 → integer=8, decimal=50)
    function getMyVWUFormatted()
        external view
        returns (uint256 integer, uint256 decimal)
    {
        uint256 v = vwu[msg.sender];
        integer = v / 100;
        decimal = v % 100;
    }

    /// @notice How much VWU remains until the next status level (caller only)
    function myVWUToNextStatus()
        external view
        returns (uint256 needed, Status next)
    {
        uint256 v = vwu[msg.sender];
        if (v < VWU_SELFLY)     return (VWU_SELFLY     - v, Status.SELFLY);
        if (v < VWU_UNIVERSAL)  return (VWU_UNIVERSAL  - v, Status.UNIVERSAL);
        if (v < VWU_HONORIS)    return (VWU_HONORIS    - v, Status.HONORIS);
        if (v < VWU_LUMINARE)   return (VWU_LUMINARE   - v, Status.LUMINARE);
        if (v < VWU_VERITAS_ZK) return (VWU_VERITAS_ZK - v, Status.VERITAS_ZK);
        return (0, Status.VERITAS_ZK);
    }

    // ══════════════════════════════════════════════════════════════════════
    // VIEW — PUBLIC (aggregated, no identity attached)
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Distribution of participants across status levels
    /// @dev Public — shows how many stars of each color exist.
    ///      Whose they are is not disclosed.
    function getStatusDistribution()
        external view
        returns (
            uint256 solo,
            uint256 selfly,
            uint256 universal,
            uint256 honoris,
            uint256 luminare,
            uint256 veritas_zk
        )
    {
        solo       = statusCount[Status.SOLO];
        selfly     = statusCount[Status.SELFLY];
        universal  = statusCount[Status.UNIVERSAL];
        honoris    = statusCount[Status.HONORIS];
        luminare   = statusCount[Status.LUMINARE];
        veritas_zk = statusCount[Status.VERITAS_ZK];
    }

    /// @notice Preview delta without writing to state (for off-chain simulation)
    /// @dev Uses msg.sender — caller previews their own potential delta only
    function previewMyDelta(
        uint8 steps_completed,
        bool  aligned_majority
    ) external view returns (uint256 delta) {
        if (steps_completed > 7) return 0;

        uint256 A             = uint256(steps_completed) * 100 / CYCLE_STEPS;
        uint256 Q             = aligned_majority ? 100 : 50;
        uint256 base_delta    = (40 * A + 60 * Q) / 100;
        uint256 current       = vwu[msg.sender];
        uint256 growth_factor = 10000 * 100 / (100 * 100 + current);
        delta                 = base_delta * growth_factor / 10000;
    }

    // ══════════════════════════════════════════════════════════════════════
    // INTERNAL
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Compute status from a VWU value
    function _computeStatus(uint256 v) internal pure returns (Status) {
        if (v >= VWU_VERITAS_ZK) return Status.VERITAS_ZK;
        if (v >= VWU_LUMINARE)   return Status.LUMINARE;
        if (v >= VWU_HONORIS)    return Status.HONORIS;
        if (v >= VWU_UNIVERSAL)  return Status.UNIVERSAL;
        if (v >= VWU_SELFLY)     return Status.SELFLY;
        return Status.SOLO;
    }

    // ══════════════════════════════════════════════════════════════════════
    // ADMIN
    // ══════════════════════════════════════════════════════════════════════

    function setCoordinator(address _coordinator) external onlyOwner {
        coordinator = _coordinator;
    }
}
