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
 * Version: 0.8
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
 *   Where this computation runs (lens B5 revision, 10.10.2026): in the
 *   protocol, before updateVWU is called. This contract receives the result
 *   and bounds it. See the note on SessionResult below.
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
  * TRAJECTORY DISCLOSURE BOUNDARY (v0.6, revised v0.8):
 *
 *   No per-participant value is written to the event log and no per-participant
 *   getter is exposed — none at all after the lens B4 revision, which removed
 *   the personal getters outright. A participant sees their own colours and
 *   points in the application, which is where that has always been served;
 *   this contract serves no one personally. Events carry counters and the
 *   status distribution only. The coordinator writes a record and learns the
 *   delta of the session it coordinated. No third party can assemble the
 *   participation trajectory of an address from the getters and the event
 *   fields of this contract.
 *
 *   That last sentence is narrower than it first reads, and the limit is
 *   stated here rather than found later. Each counter below is published on
 *   every event that moves it, so what the log holds is not an aggregate but a
 *   numbered notice: consecutive values differ by one participant, and the
 *   transaction that caused the move stands beside them. A status change is
 *   published at the moment it happens, inside the coordinator's call, which
 *   carries that session's list. The fields name no one; the moment and the
 *   neighbour do that work instead. Audit lens B4.
 *
 *   Scope of the guarantee: this removes the public API and the indexed log —
 *   the two channels that make bulk collection cheap. Solidity `private` is a
 *   compile-time visibility rule, not confidentiality: storage slots remain
 *   readable off-chain. Plaintext-free storage of the balance (commitment plus
 *   ZK proof of the delta) is a Phase 2 design item, not a patch.
 *
 *   Third channel, closed by the lens B5 revision: the arguments of the call
 *   that applies a session. They used to carry the inputs of the calculation
 *   per participant — completed steps, prompt flags, support level for each
 *   agenda dilemma — in the open. The protocol now computes the contribution
 *   and submits the result alone. What this costs is stated plainly: the
 *   computation is no longer reproducible from the contract, so correctness of
 *   a credit is not checkable by a third party today. A ZK proof of the credit
 *   closes that, and it belongs with plaintext-free storage of the balance —
 *   the same Phase 2 item, not a separate one.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * AGGREGATE DISCLOSURE (lens B4):
 *
 *   The quantities published here — three running totals and the status
 *   distribution — are counting queries. One participant moves each of them by
 *   exactly one, which is the worst case by definition, and the loss from
 *   publishing them accumulates with every release: there is no number of
 *   releases after which it stops growing. For a counter maintained publicly
 *   over a run of rounds, an error on the order of the logarithm of that run is
 *   a lower bound — an exact public counter and privacy of the run are not both
 *   available. Dwork and Roth, The Algorithmic Foundations of Differential
 *   Privacy, 2014: definition 3.1, theorem 3.20, theorem 12.6.
 *
 *   None of this is applied as a remedy. The noise those results assume would
 *   cost the one thing the counters are kept for: a third party being able to
 *   recompute the result while set equality remains unproven. The source names
 *   the leak and measures it; what closes it is a proof of set equality, which
 *   is not established. See docs/AUTHORITY_CHAIN.md §11.
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
 *   Two participants who chose the same side may carry different weight
 *   depending on how many of the seven steps they completed.
 *   steps_completed: 0 = no participation, 7 = full cycle.
 *   The sides of a dilemma are Option A and Option B. There is no third
 *   button, and silence is a recorded state of its own, never an abstention
 *   and never missing data. The line quoted from preprint [12] — «the dilemma
 *   remains binary — yes or no — but the seven steps measure the seriousness
 *   of the path toward that binary choice» — keeps the earlier wording of the
 *   published text; the wording above is the protocol's own.
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

    /// @dev `[PROTECTED]`: the name and the type are public, the operative
    ///      number is in the master document under NDA. Seven figures stand in
    ///      that position here — the six thresholds below and the ceiling under
    ///      them — and each carries the marker on its own line, because a
    ///      number without one reads as operative. VWU_BASE above carries no
    ///      marker on purpose: the non-burnable floor is a published figure.
    ///      This matters to the audit and not only to confidentiality — a
    ///      threshold is public and its crossing is published, so a reader who
    ///      takes these as operative reads a bound on somebody's rating out of
    ///      a status event.
    ///
    ///      These six numbers exist twice. BeTrueCoreCore.sol declares its own
    ///      set under the same names and runs its own _computeStatus over them,
    ///      and nothing compares the two: the engine's statusCount and the
    ///      status written into a participant's record are computed by separate
    ///      copies of one table. The rule is stated elsewhere in this project —
    ///      two places holding one threshold is how they drift apart
    ///      (HarmonyAgent.sol, at the CRITICAL band) — and here it is not kept.
    ///      Until one file reads the other, a threshold changes in both or in
    ///      neither.
    ///
    ///      One relation the operative values have to keep, whatever they are:
    ///      VWU_CAP stands above the highest threshold, never on it. At the
    ///      values below the two are equal at 3000, so the top band is a single
    ///      point — a rating reaches VERITAS_ZK only by sitting exactly at the
    ///      ceiling.
    // Status thresholds
    uint256 public constant VWU_SOLO       = 0;     // [PROTECTED]
    uint256 public constant VWU_SELFLY     = 100;   // [PROTECTED] 1.00 VWU
    uint256 public constant VWU_UNIVERSAL  = 300;   // [PROTECTED] 3.00 VWU
    uint256 public constant VWU_HONORIS    = 700;   // [PROTECTED] 7.00 VWU
    uint256 public constant VWU_LUMINARE   = 1500;  // [PROTECTED] 15.00 VWU
    uint256 public constant VWU_VERITAS_ZK = 3000;  // [PROTECTED] 30.00 VWU

    /// @notice Upper bound on VWU accumulation — normative architectural principle
    /// @dev Bounded accumulation is a normative constraint, not a technical one
    ///      — preprint [11]. The number below is illustrative, on the same
    ///      footing as the six thresholds above; the operative bound follows
    ///      the master document.
    uint256 private constant VWU_CAP = 3000; // [PROTECTED]

    /// @notice Steps in the seven-step participation cycle
    uint256 public constant CYCLE_STEPS = 7;

    /// @notice Agenda topics selected collectively per session — always three
    /// @dev Preprint [12]: steps 5–7 are binary choices over the TOP-3 agenda
    uint256 public constant AGENDA_TOPICS = 3;

    // ══════════════════════════════════════════════════════════════════════
    // ENUMS
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Participant status levels based on accumulated VWU
    /// @dev Status reflects accumulated activity and utility of judgement.
    ///      It does not express the ethical quality of any decision: ethical
    ///      assessment belongs to the 736-point map and the Harmony Agent
    ///      verdict, never to VWU.
    enum Status {
        SOLO,       // Copper   — entry level
        SELFLY,     // Bronze   — individual signal established
        UNIVERSAL,  // Titanium — consistent participation
        HONORIS,    // Silver   — sustained utility of judgement
        LUMINARE,   // Gold     — community anchor
        VERITAS_ZK  // Platinum — zero-knowledge verified standing
    }

    // ══════════════════════════════════════════════════════════════════════
    // STATE
    // ══════════════════════════════════════════════════════════════════════

    /// @notice VWU balance per participant
    /// @dev Not exposed, and not readable here at all: a participant sees
    ///      their own balance in the application.
    ///      Preprint [11]: «VWU status is not a public attribute»
    mapping(address => uint256) private vwu;

    /// @notice Last session timestamp per participant
    /// @dev Not exposed — a per-address timestamp series is a linkage channel.
    ///      Written here, read by nothing in this contract after the lens B4
    ///      revision removed the personal getters. Kept because it is part of
    ///      the participant's record, which personal reading returns to in
    ///      Phase 2: a storage cost carried deliberately, not an oversight.
    mapping(address => uint256) private lastSessionTimestamp;

    /// @notice Session count per participant
    /// @dev Not exposed — a per-address session count is a linkage channel.
    ///      Written here, read by nothing in this contract after the lens B4
    ///      revision; kept on the same ground as the timestamp above.
    mapping(address => uint256) private sessionCount;

    /// @notice Registration flag (distinguishes VWU_BASE from unregistered)
    /// @dev Not exposed. The coordinator checks it via isRegistered().
    mapping(address => bool) private registered;

    /// @notice Count of participants at each status level
    /// @dev Public — shows how many «stars» at each level, not whose they are.
    ///      Like stars in the sky: visible count, anonymous ownership.
    mapping(Status => uint256) public statusCount;

    /// @notice Aggregate counters — the only quantities the event log carries
    uint256 public registeredTotal;
    uint256 public updatesTotal;
    uint256 public filterTotal;

    /// @notice Address holding the registrar role of this engine
    /// @dev Named for how it begins, not for what it is: the deploying address
    ///      receives the role, and from there it passes on — DEPLOYER HANDOVER
    ///      at the end of this file, two steps, through the acting holder
    ///      alone. The position on the temporariness of protocol roles is
    ///      stated once, at the coordinator field in Poll.sol.
    ///
    ///      Correcting what stood here (audit lens B8). This field used to be
    ///      described as holding no authority over participants. That is not
    ///      so: setCoordinator below decides which contract may call
    ///      initializeParticipant and updateVWU, so this address can point the
    ///      engine at a contract of its own and then credit any rating to any
    ///      address. Weight is what a participant's vote counts for, so this is
    ///      authority over participants in the fullest sense, and it is the
    ///      strongest single power in the package — stronger than opening
    ///      sessions, stronger than writing the tree root, because it rewrites
    ///      the measure rather than the membership. Named here rather than
    ///      softened. The boundary is in docs/AUTHORITY_CHAIN.md, §14.
    address public deployer;

    /// @notice Address named to take over the registrar role, not yet in force
    address public pendingDeployer;

    /// @notice The contract allowed to call this engine
    /// @dev Not a person and not a key holder: in the deployed package this is
    ///      BeTrueCoreCore, which registers participants and applies session
    ///      results. The human coordinator role sits one level up, in
    ///      BeTrueCoreCore and Poll, and reaches this engine only through that
    ///      contract. So this pointer passes in one step rather than two: a
    ///      contract cannot claim a role by calling for itself, and requiring
    ///      it to would mean a handover function inside BeTrueCoreCore that
    ///      nothing else needs.
    address public coordinator;

    // ══════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Session contribution submitted by the protocol after time lock
    /// @dev What this struct carries, and why it carries nothing else.
    ///      The inputs of the calculation — completed steps, prompt submitted,
    ///      prompt in agenda, and the support level recorded for each of the
    ///      three agenda dilemmas — are a per-person record of how someone
    ///      responded. Passing them to a contract means publishing them: the
    ///      arguments of a call are visible on the peer-to-peer network before
    ///      any block holds them and remain in the chain's history afterwards,
    ///      next to the commitment they belong to. The key rotation of L1
    ///      protects a choice up to the reveal; this is the step after it.
    ///      So the protocol computes the contribution itself and submits the
    ///      result. What crosses into L2 is one signed number per participant.
    ///      Audit lens B5; see docs/AUTHORITY_CHAIN.md §11.
    struct SessionResult {
        address participant;

        /// @notice Session contribution, already computed, in VWU units ×100
        /// @dev Signed: the rational filter yields a negative value. Bounds are
        ///      applied here, not there — VWU_BASE as the floor, VWU_CAP as the
        ///      ceiling — so a wrong value cannot drive a rating out of range.
        int256  delta;

        uint256 session_timestamp;
    }

    // ══════════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════════
    //
    // No event carries an address or a per-participant value. That is a
    // statement about the fields, not about what the log discloses. Each event
    // below is emitted at the moment of the act it reports: a registration
    // event shares its transaction with the participant's own call to the
    // protocol, and a session event is emitted inside the coordinator's batch,
    // beside the list that batch carries. The level protected here is the
    // event, not the participant — one interaction is unnamed, a run of them
    // is not. Audit lens B4; see the trajectory note in the header.

    /// @notice A participant was registered — running total only
    /// @dev The total is published on each registration, so the series is a
    ///      per-event notice with a sequence number: the n-th value belongs to
    ///      the n-th registrant, whose own transaction carries this call. The
    ///      count is kept deliberately — while set equality remains unproven,
    ///      a published aggregate is the only thing a third party can recompute
    ///      the result from. What that costs is recorded here, not argued away.
    event ParticipantInitialized(uint256 registered_total);

    /// @notice A session result was applied — running total only
    event VWUUpdated(uint256 updates_total);

    /// @notice The rational filter was recorded against a participation —
    ///         running total only
    /// @dev Read the name against what the code does. This counter rises on
    ///      every negative contribution submitted, whether or not anything came
    ///      off the rating: a participant already at the non-burnable floor
    ///      keeps every point — _apply returns VWU_BASE — and the event is
    ///      emitted all the same, because the filter was recorded even where it
    ///      could take nothing. In a young community that is the ordinary case,
    ///      not the exception, so "reduced a rating" would be wrong most of the
    ///      time it fires.
    ///      This counter differs in kind from the two above. It does not report
    ///      that someone participated but that someone's choices were recorded
    ///      as gamification abuse, and it is emitted inside the coordinator's
    ///      call for that session. The number of filter events in a session,
    ///      read beside the list that session carries, publishes a rate of
    ///      recorded abuse for a named group. The filter is inferred here from
    ///      the sign of the delta, the rating being reducible by nothing else.
    ///      Whether this counter earns its publication is a question for the
    ///      MVP trials, not for this audit.
    event RationalFilterApplied(uint256 filter_total);

    /// @notice The status distribution changed at one level — level and its count
    /// @dev The number carried is not the disclosure; the emission is. The
    ///      event fires exactly when someone crosses a threshold, the
    ///      thresholds are public constants, and the crossing is published
    ///      inside the call that names the session's participants.
    ///      Registration emits it too, every time, because the base score
    ///      already sits at the first threshold — so each new participant
    ///      produces this event and the one above it in the same transaction.
    event StatusAdvanced(Status new_status, uint256 count_at_level);

    /// @notice Emitted when the coordinator role is reassigned
    /// @dev Both addresses are roles of the protocol, never participants. The
    ///      power to set this role stays where it was; what is removed is the
    ///      silence around using it.
    event CoordinatorChanged(address indexed previous, address indexed current);

    // ══════════════════════════════════════════════════════════════════════
    // ERRORS
    // ══════════════════════════════════════════════════════════════════════

    error NotCoordinator();
    error NotDeployer();
    error NotProposedDeployer();
    error AlreadyRegistered(address participant);
    error NotRegistered(address participant);

    // ══════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ══════════════════════════════════════════════════════════════════════

    constructor(address _coordinator) {
        deployer    = msg.sender;
        coordinator = _coordinator;
    }

    // ══════════════════════════════════════════════════════════════════════
    // MODIFIERS
    // ══════════════════════════════════════════════════════════════════════

    modifier onlyCoordinator() {
        if (msg.sender != coordinator) revert NotCoordinator();
        _;
    }

    modifier onlyDeployer() {
        if (msg.sender != deployer) revert NotDeployer();
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

        Status entry = _computeStatus(VWU_BASE);
        statusCount[entry]++;
        registeredTotal++;

        emit ParticipantInitialized(registeredTotal);
        emit StatusAdvanced(entry, statusCount[entry]);
    }

    // ══════════════════════════════════════════════════════════════════════
    // CORE — UPDATE VWU
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Update VWU after a session (called by coordinator after time lock)
    /// @dev Silence is sovereign — absence never reduces VWU and never reduces
    ///      the next session delta. The rating is frozen for that period.
    /// @param result Session contribution from the protocol
    /// @return delta_applied Session delta applied to the participant's rating
    function updateVWU(SessionResult memory result)
        external onlyCoordinator returns (int256 delta_applied)
    {
        address p = result.participant;

        if (!registered[p]) revert NotRegistered(p);

        Status status_before = _computeStatus(vwu[p]);

        // ── Step 1: Session delta ──────────────────────────────────────────
        // Computed by the protocol before this call: Activity 40% + Utility
        // 60%, with the component limits, the support-level scale and the
        // growth factor held in the master document (NDA required). The
        // contract receives the result and bounds it; it does not see what the
        // result was computed from. Why not: the inputs are per-person records
        // of how someone responded, and a call's arguments are public — see
        // the note on SessionResult above.
        uint256 current = vwu[p];
        int256  delta   = result.delta;

        if (delta < 0) {
            filterTotal++;
            emit RationalFilterApplied(filterTotal);
        }

        // ── Step 2: Apply delta within bounds ──────────────────────────────
        // Preprint [11]: «no participant can accumulate unlimited weight»
        uint256 new_vwu = _apply(current, delta);
        if (new_vwu > VWU_CAP) new_vwu = VWU_CAP;

        vwu[p]                  = new_vwu;
        lastSessionTimestamp[p] = result.session_timestamp;
        sessionCount[p]++;
        updatesTotal++;

        emit VWUUpdated(updatesTotal);

        // ── Step 3: Update status distribution and emit event ──────────────
        // statusCount is public — shows how many stars at each level,
        // not whose they are.
        //
        // Not whose, taken alone. This event is emitted inside the
        // coordinator's call, the same call that carries the session's list of
        // commitments in its arguments — so an observer sees the distribution
        // move and sees the list it moved for, together, before the block.
        // The event names no one; its neighbour in the same call does. Passed
        // to B4 as a question of aggregates; here it is a question of timing.
        Status status_after = _computeStatus(new_vwu);
        if (status_after != status_before) {
            if (statusCount[status_before] > 0) {
                statusCount[status_before]--;
            }
            statusCount[status_after]++;
            emit StatusAdvanced(status_after, statusCount[status_after]);
        }

        // The caller learns the delta of the session it coordinated —
        // never another participant's accumulated rating.
        delta_applied = int256(new_vwu) - int256(current);
    }

    // ══════════════════════════════════════════════════════════════════════
    // VIEW — PERSONAL: none
    // ══════════════════════════════════════════════════════════════════════
    //
    // Removed by the lens B4 revision: getMyStatus, getMyVWU,
    // getMyVWUFormatted, myVWUToNextStatus, getMyLastSession,
    // getMySessionCount, amIRegistered.
    //
    // They were keyed by msg.sender, while the record they were meant to serve
    // is keyed by an address derived from the identity commitment — an address
    // no one holds a key to. A participant calling them read an empty record,
    // never their own. Seven functions that answer nothing are worse than none:
    // their names make a promise the wiring does not keep.
    //
    // Nothing that was being served is lost. A participant sees their own
    // colours and points in the application; the Panorama publishes the
    // collective result — the roster total at its head, then Option A, Option
    // B and silence, each as a count and the sum of the weight behind it, with
    // a traffic light on each of the two sides and none on silence — and that
    // division is the design, not a shortcoming of this contract. On-chain personal reading returns
    // when the balance moves to plaintext-free storage, and it returns served
    // by a proof of ownership rather than by a caller address — the same
    // Phase 2 item as the storage itself.

    

    // ══════════════════════════════════════════════════════════════════════
    // VIEW — COORDINATOR
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Registration check for the coordinator contract
    /// @dev Replaces the former public `registered` mapping getter.
    function isRegistered(address participant)
        external view onlyCoordinator returns (bool)
    {
        return registered[participant];
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

    // Removed: previewMyDelta. It ran the protected calculation locally for
    // anyone who called it, leaving no record anywhere, and after the lens B5
    // revision there is nothing here to run — the calculation lives in the
    // protocol. A participant previews their own potential contribution in the
    // application, where the formula is.

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

    // Removed: _baseDelta. The computation it stood for now runs in the
    // protocol, before updateVWU is called — see the note on SessionResult.
    // Its composition is unchanged: Activity 40% + Utility 60%, with component
    // limits, the support-level scale and the non-linear growth factor held in
    // the BeTrueCore master document (OpenTimestamps SHA-256), NDA required.
    // The Harmony Agent traffic-light verdict is not an input to it: it is an
    // ethical indication displayed by the Panorama, applied to each side of a
    // dilemma separately — Option A and Option B alike, by one and the same
    // measure — while silence receives no colour at all. It does not affect
    // participant weight.

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
    // DEPLOYER HANDOVER
    //
    // Two steps, the same shape as the handovers in Poll.sol,
    // BeTrueCoreCore.sol, NINNullifierRegistry.sol, EthicalMatrix.sol and
    // HarmonyAgent.sol: the acting holder names a successor, and the successor
    // takes the role by its own call, which is how it shows it holds the key. A
    // one-step setter would hand the power described at the deployer field to a
    // mistyped address with no way back. Naming a different address replaces an
    // unaccepted proposal; there is no separate cancel.
    //
    // The cost, stated rather than hidden: if the key is lost, the pointer can
    // never be moved again. That is survivable here and not elsewhere — the
    // engine keeps working for the coordinator contract it already points at,
    // and only replacing that contract becomes impossible. No address outside
    // the role is given a way round, because such a way is itself the capture
    // surface.
    //
    // What a handover does not change: the successor inherits the same
    // unconstrained power over the measure. Reducing it is not a matter of who
    // holds the role — it needs the credit itself to be provable, which is the
    // Phase 2 item named in the trajectory note at the head of this file and
    // the first row of the table in docs/AUTHORITY_CHAIN.md, §14. Both events
    // carry updatesTotal, so the archive shows where in the run of applied
    // sessions the role changed hands. Audit lens B8.
    // ══════════════════════════════════════════════════════════════════════

    /// @notice The acting holder named a successor. Nothing has moved yet.
    event DeployerHandoverProposed(address indexed proposed, uint256 updates_total);

    /// @notice The role passed. updates_total fixes where in the run of
    ///         applied sessions it happened.
    event DeployerTransferred(
        address indexed previous,
        address indexed current,
        uint256 updates_total
    );

    /// @notice Name the address that may take over the registrar role
    function proposeDeployer(address proposed) external onlyDeployer {
        require(proposed != address(0), "Zero address");
        require(proposed != deployer, "Already registrar");

        pendingDeployer = proposed;
        emit DeployerHandoverProposed(proposed, updatesTotal);
    }

    /// @notice Take over the registrar role, called by the named address
    function acceptDeployer() external {
        if (msg.sender != pendingDeployer) revert NotProposedDeployer();

        address previous = deployer;
        deployer         = msg.sender;
        pendingDeployer  = address(0);

        emit DeployerTransferred(previous, msg.sender, updatesTotal);
    }

    // ══════════════════════════════════════════════════════════════════════
    // REGISTRAR
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Replace the contract allowed to call this engine
    /// @dev The change is announced. Done during an open session it strands
    ///      that session: every entry point here is behind onlyCoordinator,
    ///      and the previous contract can no longer apply its results.
    ///      What the announcement does not do is make the change checkable.
    ///      The event carries the two addresses and nothing about what the new
    ///      pointer is: a reader cannot tell the deployed BeTrueCoreCore from
    ///      any other contract that fits the same calls. Pairing this pointer
    ///      with the contract the community actually runs is organisational,
    ///      and it is to be named as organisational wherever the chain of
    ///      authority is described. Audit lens B8.
    function setCoordinator(address _coordinator) external onlyDeployer {
        require(_coordinator != address(0), "Zero address");

        address previous = coordinator;
        coordinator = _coordinator;
        emit CoordinatorChanged(previous, _coordinator);
    }
}
