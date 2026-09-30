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
 * Version: 0.5
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
 * FORMULA — PUBLIC PART (preprint [11], DOI: 10.5281/zenodo.22179301;
 * the published version describes an earlier formulation of the second
 * component and is superseded here):
 *
 *   Session contribution combines two weighted components:
 *       Activity 40% + Utility 60%
 *
 *   Component limits, the support-level scale, memory length and adaptation
 *   coefficients are protected in the BeTrueCore master document
 *   (OpenTimestamps SHA-256). NDA required.
 *
 *   A — activity coefficient ∈ [0,100]
 *       Reflects depth of the seven-step cycle:
 *       A = steps_completed × 100 / 7
 *       0 steps = 0, 7 steps = 100
 *
 *   Two weighted contribution components:
 *       Activity — 40%   participation depth and agenda formation
 *       Utility  — 60%   judgments on the dilemmas within the agenda
 *
 *   No running tally is exposed. The participant cannot observe the
 *   distribution of choices at the moment of choosing.
 *
 * Full specification (non-linear factor, EMA parameters, momentum) is
 * protected in the BeTrueCore master document (OpenTimestamps SHA-256).
 * NDA required.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * KEY PROPERTIES:
 *
 *   1. Irreversibility of base score  — VWU never falls below VWU_BASE.
 *                                       Absence does not reduce it; only a
 *                                       recorded rational-filter violation
 *                                       reduces the rating above that floor
 *   2. Bounded accumulation           — VWU cannot exceed VWU_CAP
 *                                       preprint [11]: «boundedness is not a
 *                                       technical constraint but a normative one»
 *   3. Non-linear growth              — diminishing returns; instantaneous
 *                                       accumulation is architecturally impossible
 *   4. Silence as sovereign decision  — absence does NOT reduce VWU and does
 *                                       NOT reduce the next session delta;
 *                                       the rating is frozen for that period
 *   5. Non-reproducibility            — behavioral trajectory cannot be fabricated at scale
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * RATIONAL FILTER:
 *
 *   The goal and the time limit are identical for every participant.
 *   If a participant makes mutually exclusive (paradoxical) or purely chaotic
 *   choices, the system records this as gamification abuse and the rating is
 *   reduced.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * OPTIONAL FACTOR:
 *
 *   VWU reflects only the days on which the participant was genuinely active.
 *   Inactive days do not affect the rating: it is frozen for that period, and
 *   those days are reported to the participant as potential gains forgone.
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
    uint256 public constant VWU_BASE = 100; // 1.00 VWU

    // Status thresholds
    uint256 public constant VWU_SOLO       = 0;
    uint256 public constant VWU_SELFLY     = 100;   // 1.00 VWU
    uint256 public constant VWU_UNIVERSAL  = 300;   // 3.00 VWU
    uint256 public constant VWU_HONORIS    = 700;   // 7.00 VWU
    uint256 public constant VWU_LUMINARE   = 1500;  // 15.00 VWU
    uint256 public constant VWU_VERITAS_ZK = 3000;  // 30.00 VWU

    /// @notice Upper bound on VWU accumulation — normative architectural principle
    /// @dev Bounded accumulation is a normative constraint, not a technical one
    ///      — preprint [11]. The value below is a placeholder for the reference
    ///      implementation; the operative bound follows the master document.
    uint256 private constant VWU_CAP = 3000; // [PLACEHOLDER]

    /// @notice Steps in the seven-step participation cycle
    uint256 public constant CYCLE_STEPS = 7;

    /// @notice Agenda topics selected collectively per session — always three
    /// @dev Preprint [12]: steps 5–7 are binary choices over the TOP-3 agenda
    uint256 public constant AGENDA_TOPICS = 3;

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

    /// @notice Last session timestamp per participant
    mapping(address => uint256) public lastSessionTimestamp;

    /// @notice Session count per participant
    mapping(address => uint256) public sessionCount;

    /// @notice Registration flag (distinguishes VWU_BASE from unregistered)
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

        /// @notice Whether the participant submitted a prompt in this session
        bool     prompt_submitted;

        /// @notice Whether the submitted prompt entered the TOP-3 agenda
        bool     prompt_in_agenda;

        /// @notice Support level recorded for each agenda dilemma
        /// @dev Array length equals AGENDA_TOPICS. The support-level scale
        ///      is protected in the master document.
        uint8[3] dilemma_support;

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
        int256  delta,
        uint8   steps_completed
    );

    event RationalFilterApplied(
        address indexed participant,
        uint256 reduction
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
    /// @dev Assigns VWU_BASE — the irreversible base score.
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
        statusCount[_computeStatus(VWU_BASE)]++;

        emit ParticipantInitialized(participant, VWU_BASE);
    }

    // ══════════════════════════════════════════════════════════════════════
    // CORE — UPDATE VWU
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Update VWU after a session (called by coordinator after time lock)
    /// @dev Silence is sovereign — absence never reduces VWU and never reduces
    ///      the next session delta. The rating is frozen for that period.
    /// @param result Session result from the anti-collusion coordinator
    /// @return delta_applied Session delta applied to the participant's rating
    function updateVWU(SessionResult memory result)
        external onlyCoordinator returns (int256 delta_applied)
    {
        address p = result.participant;

        if (!registered[p])             revert NotRegistered(p);
        if (result.steps_completed > 7) revert InvalidStepsCompleted(result.steps_completed);

        Status status_before = _computeStatus(vwu[p]);

        // ── Step 1: Session delta ──────────────────────────────────────────
        // Activity 40% + Utility 60%. Component limits, the support-level
        // scale and the growth factor are protected (NDA required).
        uint256 current = vwu[p];
        int256  delta   = _baseDelta(result);

        if (delta < 0) emit RationalFilterApplied(p, uint256(-delta));

        // ── Step 2: Apply delta within bounds ──────────────────────────────
        // Preprint [11]: «no participant can accumulate unlimited weight»
        uint256 new_vwu = _apply(current, delta);
        if (new_vwu > VWU_CAP) new_vwu = VWU_CAP;

        vwu[p]                  = new_vwu;
        lastSessionTimestamp[p] = result.session_timestamp;
        sessionCount[p]++;

        emit VWUUpdated(p, new_vwu, delta, result.steps_completed);

        // ── Step 3: Update status distribution and emit event ──────────────
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

        // The caller learns the delta of the session it coordinated —
        // never another participant's accumulated rating.
        delta_applied = int256(new_vwu) - int256(current);
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
    /// @dev Caller previews their own potential delta only
    function previewMyDelta(SessionResult memory result)
        external view returns (int256 delta)
    {
        if (result.participant != msg.sender) return 0;
        if (result.steps_completed > 7)       return 0;

        delta = _baseDelta(result);
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

    /// @notice Session delta derived from the session result
    /// @dev Return value is in VWU units ×100, the same scale as vwu[] storage.
    ///      Composition: Activity 40% + Utility 60%. Component limits, the
    ///      support-level scale and the non-linear growth factor are protected
    ///      in the BeTrueCore master document (OpenTimestamps SHA-256).
    ///      NDA required.
    ///      The Harmony Agent traffic-light verdict is not an input here. It is
    ///      an ethical indication displayed by the Panorama, applied to majority
    ///      and minority alike, and it does not affect participant weight.
    function _baseDelta(SessionResult memory result)
        internal view returns (int256 delta)
    {
        // [PROTECTED — implementation per master document]
    }

    /// @notice Apply a session delta to the cumulative rating
    /// @dev Both current and return value are in VWU units ×100.
    ///      The result never falls below VWU_BASE — «Varlıq özü imzadır».
    function _apply(uint256 current, int256 delta)
        internal pure returns (uint256)
    {
        int256 result = int256(current) + delta;
        if (result < int256(VWU_BASE)) return VWU_BASE;
        return uint256(result);
    }

    // ══════════════════════════════════════════════════════════════════════
    // ADMIN
    // ══════════════════════════════════════════════════════════════════════

    function setCoordinator(address _coordinator) external onlyOwner {
        coordinator = _coordinator;
    }
}

