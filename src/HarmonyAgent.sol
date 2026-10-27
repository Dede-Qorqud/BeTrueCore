// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./EthicalMatrix.sol";

/// @title HarmonyAgent
/// @notice Aggregates Ematch scores across activated cells and computes the final traffic light verdict
/// @dev Part of BeTrueCore Developer Package v0.3
/// @author Farman Guliyev (Safarnur) — github.com/Dede-Qorqud/BeTrueCore
///
/// Formula, per option: Ematch_final = Σ(Ematch_ij × weight_ij) / Σ(weight_ij)
/// Verdict: RED [0–40) · YELLOW [40–70) · GREEN [70–100]
///          UNDETERMINED — nothing was measurable on that side
///
/// TWO VERDICTS, ONE PER OPTION
/// ───────────────────────────
/// The traffic light is applied to each side of the dilemma separately —
/// Option A and Option B alike — so each side receives its own colour. Equal
/// application means one measure: the same 736-point map, the same thresholds,
/// not one colour. On the Panorama a reader sees which side was larger and may
/// call them majority and minority there; this contract never does, and the
/// paragraph below says why. A numerical majority is not thereby right, and a
/// small minority is not thereby wrong. The matrix does not choose sides; it
/// measures both, and says so separately.
///
/// The two are keyed by option, never by majority and minority. This contract
/// is never told which side was larger, and that is what makes equal
/// application a property rather than a promise: a verdict computed in
/// ignorance of the sizes cannot be softened for the larger side. The counts
/// live in SessionResult, where the Panorama reads them.
///
/// Silence receives no verdict. It is a choice and a sovereign signal, and it
/// is measured — by the weight that stayed silent, which the Panorama publishes
/// and which measures the dilemma rather than the people who withheld. The map
/// measures the integrity of a decision taken, and silence forms no decision to
/// measure. Nothing is left without a response; the responses are of different
/// kinds.
///
/// Provenance of the inputs. The weights come from the matrix and are fixed.
/// The ematch scores do not: the Harmony Agent chooses which cells a dilemma
/// touches, reads the result of the vote as the Panorama shows it, applies the
/// map to each side and reports the scores together with its own conclusion. It
/// is a language model, and a score is testimony, not a measurement taken by
/// the protocol. The arithmetic below is exact over inputs that are not
/// themselves guaranteed, so every bound this contract can place on them is
/// enforced here and not assumed of the sender.
///
/// Why the chain recomputes. The agent submits its conclusion, and this
/// contract does not take it: it recomputes the verdict from the submitted
/// cells and scores and records both — the agent's conclusion and its own
/// result, side by side. Where they disagree, the disagreement stays in the
/// archive. Prompt injection cannot be removed (lens B1), and a steered agent
/// leaving a trace is what remains available against it. Accepting a finished
/// verdict would have cost the one property the whole protocol is built for:
/// a third party being able to check that the threshold was applied honestly.
/// AI is the notary; the map is what judges.
///
/// What is not wired yet, and is to be read together with the paragraph above.
/// No contract of this package calls computeFinalVerdict. BeTrueCoreCore holds
/// a pointer to this contract and never uses it: finalizeSession stores the two
/// verdicts that arrive in the submitted SessionResult, and nothing compares
/// them with anything computed here. The recomputation therefore exists and
/// emits its events, but it stands beside the finalization path rather than on
/// it — a coordinator may compute here and finalize with different verdicts,
/// and no check notices. Until finalizeSession takes its verdicts from this
/// computation, or refuses a result that disagrees with it, "the chain
/// recomputes" names a function that is available, not a guarantee that is
/// enforced, and every text of this project is to say so. Closing it is a
/// revision of the finalization path, not a correction to this file.

contract HarmonyAgent {

    // ─────────────────────────────────────────────────────────────
    // STATE
    // ─────────────────────────────────────────────────────────────

    EthicalMatrix public matrix;

    /// @notice Address holding the registrar role of this agent
    /// @dev Named for how it begins, not for what it is: the deploying address
    ///      receives the role, and from there it passes on — proposeDeployer
    ///      and acceptDeployer below, two steps, through the acting holder
    ///      alone. The position on the temporariness of protocol roles is
    ///      stated once, at the coordinator field in Poll.sol.
    ///
    ///      Correcting what stood here (audit lens B8). This field used to be
    ///      described as holding no authority over participants. It decides who
    ///      may compute a binding verdict, and the verdict is what the archive
    ///      keeps and the Panorama shows. Across the package the three
    ///      registrar roles divide as follows: the one in
    ///      NINNullifierRegistry.sol decides who is in the set, the one in
    ///      VWUEngine.sol decides what a participation is worth, and this one
    ///      decides who may judge. None of them is above a participant in the
    ///      session; all three are above the measures by which a session is
    ///      read. Named here rather than softened. The boundary is in
    ///      docs/AUTHORITY_CHAIN.md, §14.
    address public deployer;

    /// @notice Address named to take over the registrar role, not yet in force
    address public pendingDeployer;

    /// @notice The only address permitted to compute a binding verdict
    /// @dev By design this is the protocol itself. A human operator holds the
    ///      role only during the MVP trials, as scaffolding — not as a mode of
    ///      operation. Without the restriction, any address could write
    ///      arbitrary scores into the audit trail: the matrix admits whoever
    ///      comes through this contract.
    address public coordinator;

    modifier onlyDeployer() {
        require(msg.sender == deployer, "Not deployer");
        _;
    }

    modifier onlyCoordinator() {
        require(msg.sender == coordinator, "Only coordinator");
        _;
    }

    /// @notice Connect the coordinator permitted to finalize verdicts
    /// @dev The change is announced. The power to set this role stays where it
    ///      was; what is removed is the silence around using it. Replacing the
    ///      holder mid-session is not blocked: a verdict must not become
    ///      uncomputable because the pointer moved.
    function setCoordinator(address _coordinator) external onlyDeployer {
        require(_coordinator != address(0), "Zero address");
        address previous = coordinator;
        coordinator = _coordinator;
        emit CoordinatorChanged(previous, _coordinator);
    }

    /// @notice Name the address that may take over the registrar role
    /// @dev Two steps, the same shape as the handovers in Poll.sol,
    ///      NINNullifierRegistry.sol, VWUEngine.sol and EthicalMatrix.sol: the
    ///      successor takes the role by its own call, which is how it shows it
    ///      holds the key. A one-step setter would hand the power described at
    ///      the deployer field to a mistyped address with no way back. Naming a
    ///      different address replaces an unaccepted proposal; there is no
    ///      separate cancel.
    ///
    ///      The cost, stated rather than hidden: if the key is lost, the
    ///      verdict-computing role can never be repointed again, and the agent
    ///      keeps working for the address it already points at. No address
    ///      outside the role is given a way round that, because such a way is
    ///      itself the capture surface this lens looks for.
    function proposeDeployer(address proposed) external onlyDeployer {
        require(proposed != address(0), "Zero address");
        require(proposed != deployer, "Already registrar");

        pendingDeployer = proposed;
        emit DeployerHandoverProposed(proposed);
    }

    /// @notice Take over the registrar role, called by the named address
    function acceptDeployer() external {
        require(msg.sender == pendingDeployer, "Not the proposed registrar");

        address previous = deployer;
        deployer         = msg.sender;
        pendingDeployer  = address(0);

        emit DeployerTransferred(previous, msg.sender);
    }

    // ─────────────────────────────────────────────────────────────
    // EVENTS
    // ─────────────────────────────────────────────────────────────

    /// @notice Emitted after each verdict computation
    /// @dev Keyed by session. The verdict belongs to the collective decision,
    ///      not to a person. No field records which side anyone stood on:
    ///      with the session result public, such a field would disclose the
    ///      individual choice it is the whole architecture's job to protect.
    ///
    ///      aggregate_score is published at a resolution of one unit on a
    ///      0-100 scale, once per session, beside a roster that is public.
    ///      Read alone it says nothing about a person. Read as a series,
    ///      against the cells triggered for the same session in EthicalMatrix,
    ///      it adds a further dimension to the reconstruction described at
    ///      SessionResult in IBeTrueCore.sol: resolution and dimensionality are
    ///      what make a series of harmless figures effective against a single
    ///      record. Carried here from EthicalVerdictIssued, which was removed.
    ///      Audit lens B4.
    event VerdictComputed(
        uint256 indexed session_id,
        uint256 aggregate_score_a,
        EthicalMatrix.Verdict verdict_a,
        uint256 cells_activated_a,
        uint256 aggregate_score_b,
        EthicalMatrix.Verdict verdict_b,
        uint256 cells_activated_b
    );

    /// @notice Emitted once per computation, carrying the conclusion the agent
    ///         submitted alongside the verdict this contract computed
    /// @dev Both are recorded, always, whether they agree or not. A reader of
    ///      the archive sees what the Harmony Agent concluded and what the map
    ///      yields over the figures it supplied, and any gap between them stays
    ///      visible permanently. That gap is the trace a steered agent leaves:
    ///      injection into the text cannot be prevented, so what matters is
    ///      that it cannot pass unrecorded. Emitted even when the two match,
    ///      for the same reason silence is recorded as silence — a state a
    ///      reader has to infer from a missing record is "no data".
    event AgentConclusionRecorded(
        uint256 indexed session_id,
        EthicalMatrix.Verdict agent_verdict_a,
        EthicalMatrix.Verdict computed_verdict_a,
        EthicalMatrix.Verdict agent_verdict_b,
        EthicalMatrix.Verdict computed_verdict_b,
        bool    divergent
    );

    /// @notice Emitted when the coordinator role is reassigned
    /// @dev Both addresses are roles of the protocol, never participants.
    event CoordinatorChanged(address indexed previous, address indexed current);

    /// @notice The acting holder of the registrar role named a successor.
    ///         Nothing has moved yet.
    /// @dev No session counter is carried: this contract keeps no count of its
    ///      own, and every verdict it writes is already keyed by session in
    ///      VerdictComputed. A reader places a handover between two sessions by
    ///      the block it sits in.
    event DeployerHandoverProposed(address indexed proposed);

    /// @notice The registrar role passed to its successor
    event DeployerTransferred(address indexed previous, address indexed current);

    /// @notice Emitted once per verdict computation, reporting how many
    ///         entries of the L5 report were refused before aggregation
    /// @dev Counts only. The refused coordinates and scores are not published:
    ///      they are values an injected agent chooses, and the archive has no
    ///      reason to carry them. What the reader needs is that entries were
    ///      refused and of which kind, so that a verdict resting on a reduced
    ///      set is recognisable as one.
    event ReportEntriesRejected(
        uint256 indexed session_id,
        uint256 cells_out_of_range_a,
        uint256 scores_out_of_range_a,
        uint256 cells_out_of_range_b,
        uint256 scores_out_of_range_b
    );

    // ─────────────────────────────────────────────────────────────
    // CONSTRUCTOR
    // ─────────────────────────────────────────────────────────────

    constructor(address _matrix) {
        matrix   = EthicalMatrix(_matrix);
        deployer = msg.sender;
    }

    // ─────────────────────────────────────────────────────────────
    // CORE FUNCTION
    // ─────────────────────────────────────────────────────────────

    /// @notice The Harmony Agent's report for one side of a dilemma
    /// @dev Cells, scores, and the agent's own conclusion for that side. The
    ///      conclusion is recorded, never trusted: the verdict published by
    ///      this contract is recomputed from the cells and the scores. The
    ///      fields are grouped so that one call carries both sides without a
    ///      parameter list no one can read.
    struct SideReport {
        uint8[] asilomar_ids;
        uint8[] tdsh_ids;
        uint8[] ematch_scores;
        EthicalMatrix.Verdict agent_verdict;
    }

    /// @notice What one side's computation yielded, before anything is emitted
    struct SideOutcome {
        EthicalMatrix.Verdict verdict;
        uint256 aggregate_score;
        uint256 cells_activated;
        uint256 cells_out_of_range;
        uint256 scores_out_of_range;
    }

    /// @notice Compute the weighted Ematch verdict of each side of a session
    /// @dev No majority flag reaches this contract, by design — see the header.
    ///      Both sides go through the same internal routine, so neither can be
    ///      measured on a different scale from the other.
    /// @param session_id Session the verdicts belong to
    /// @param side_a Harmony Agent report for Option A
    /// @param side_b Harmony Agent report for Option B
    /// @return verdict_a RED / YELLOW / GREEN / UNDETERMINED for Option A
    /// @return verdict_b RED / YELLOW / GREEN / UNDETERMINED for Option B
    function computeFinalVerdict(
        uint256    session_id,
        SideReport memory side_a,
        SideReport memory side_b
    ) external onlyCoordinator returns (
        EthicalMatrix.Verdict verdict_a,
        EthicalMatrix.Verdict verdict_b
    ) {
        SideOutcome memory out_a = _computeSide(session_id, side_a);
        SideOutcome memory out_b = _computeSide(session_id, side_b);

        verdict_a = out_a.verdict;
        verdict_b = out_b.verdict;

        // Emitted on every computation, including when every count is zero. A
        // session that refused nothing says so, instead of leaving the reader
        // to infer it from an absent event. Silence is recorded as silence here
        // for the same reason it is recorded that way for a participant who did
        // not answer: a state a reader has to deduce from a missing record is
        // "no data", and this architecture does not produce that value
        // anywhere.
        emit ReportEntriesRejected(
            session_id,
            out_a.cells_out_of_range,
            out_a.scores_out_of_range,
            out_b.cells_out_of_range,
            out_b.scores_out_of_range
        );

        emit VerdictComputed(
            session_id,
            out_a.aggregate_score, verdict_a, out_a.cells_activated,
            out_b.aggregate_score, verdict_b, out_b.cells_activated
        );

        // The agent's conclusion and the recomputed verdict, recorded side by
        // side whether they agree or not. See the note at the event.
        emit AgentConclusionRecorded(
            session_id,
            side_a.agent_verdict, verdict_a,
            side_b.agent_verdict, verdict_b,
            side_a.agent_verdict != verdict_a || side_b.agent_verdict != verdict_b
        );
    }

    /// @notice Aggregate one side's report and derive its verdict
    /// @dev Writes to the audit trail through matrix.triggerCell, so it is not
    ///      a view. Emits nothing itself: both sides are computed first and the
    ///      events are written once, by the caller, so that the archive holds
    ///      one record per session rather than one per side.
    function _computeSide(
        uint256    session_id,
        SideReport memory side
    ) internal returns (SideOutcome memory outcome) {
        require(
            side.asilomar_ids.length == side.tdsh_ids.length &&
            side.tdsh_ids.length == side.ematch_scores.length,
            "Array length mismatch"
        );

        uint256 weighted_sum = 0;
        uint256 weight_total = 0;

        // A CRITICAL cell is a direct, safety-critical intersection, and a
        // breach of one is not a quantity to be averaged: with CRITICAL
        // carrying weight 3 out of 3, a single breached cell among many sound
        // ones still leaves the weighted mean in GREEN, so the arithmetic
        // contradicted what the whitepaper states the map is for. Counted here
        // and applied below: any CRITICAL cell whose own score falls in the RED
        // band forces this side's verdict to RED, whatever the mean. The band
        // is not restated as a number — matrix.computeVerdict holds the
        // thresholds, and two places holding one threshold is how they drift
        // apart. Transfer A-08, first half.
        uint256 critical_breaches = 0;

        for (uint i = 0; i < side.asilomar_ids.length; i++) {
            // Entries arrive from the Harmony Agent, a language model reading
            // participant-authored text, so an entry can be malformed without
            // anyone acting in bad faith and can be malformed by design if the
            // text steered the agent. Both are handled the same way: the entry
            // is refused, counted, and reported by the caller. It is not
            // allowed to pass into the sum, and it is not allowed to disappear
            // without trace.
            //
            // The coordinates are bounded here rather than left to the matrix.
            // Reading a cell outside 23 x 32 would otherwise return weight 0
            // and be dropped by the SUPERPOSITION rule below — a silent removal
            // of evidence, indistinguishable from a cell that simply carries no
            // weight.
            if (
                side.asilomar_ids[i] < 1 || side.asilomar_ids[i] > 23 ||
                side.tdsh_ids[i]     < 1 || side.tdsh_ids[i]     > 32
            ) {
                outcome.cells_out_of_range++;
                continue;
            }

            // The documented range of a score is 0-100 and uint8 admits 255.
            if (side.ematch_scores[i] > 100) {
                outcome.scores_out_of_range++;
                continue;
            }

            uint8 weight = matrix.getCellWeight(
                side.asilomar_ids[i],
                side.tdsh_ids[i]
            );

            // SUPERPOSITION cells (weight 0) are excluded from aggregation
            if (weight == 0) continue;

            weighted_sum += uint256(side.ematch_scores[i]) * uint256(weight);
            weight_total += uint256(weight);
            outcome.cells_activated++;

            // Weight 3 is CRITICAL — see getCellWeight in EthicalMatrix.sol.
            if (
                weight == 3 &&
                matrix.computeVerdict(side.ematch_scores[i]) ==
                    EthicalMatrix.Verdict.RED
            ) {
                critical_breaches++;
            }

            // Emit individual cell trigger to Celestia DA audit trail.
            // The record carries an agent-reported score and is not marked as
            // such: in the archive it is indistinguishable from a quantity the
            // protocol measured. Marking provenance changes the record format
            // and the L2 to L4 boundary, so it is a decision and not a fix.
            // Nor does the record say which side it belongs to — the same
            // question, one step further, and held open with it.
            matrix.triggerCell(
                session_id,
                side.asilomar_ids[i],
                side.tdsh_ids[i],
                side.ematch_scores[i]
            );
        }

        // Nothing was measurable on this side. Transfer A-08, second half. This
        // used to return GREEN with a score of 100 — a failure to read reported
        // as a clean result, and reachable by steering the agent with text
        // (lens B1).
        //
        // Two different states arrive here, and the verdict is the same for
        // both because in both there was nothing to average. They are told
        // apart by ReportEntriesRejected:
        //   both counts zero  — nothing was refused and nothing was read. No
        //                       one chose this option, or no cell activated
        //                       carried weight. A sovereign outcome, not a
        //                       fault: where no one chose at all, the Panorama
        //                       shows the figures as they are, both sides
        //                       without colour, and the weight that stayed
        //                       silent is what the session says.
        //   either count > 0  — a report arrived and was refused, in whole or
        //                       in part. A fault in the reading, accidental or
        //                       steered.
        // The distinction lives in the events, not in a further verdict value:
        // a verdict says what was measured, never why it could not be.
        //
        // The score reported alongside is 0 rather than 100: no number is
        // truthful here, and the verdict is what tells the reader the figure
        // carries no measurement.
        if (weight_total == 0) {
            outcome.verdict = EthicalMatrix.Verdict.UNDETERMINED;
            outcome.aggregate_score = 0;
            return outcome;
        }

        outcome.aggregate_score = weighted_sum / weight_total;

        // The mean is reported either way; only the verdict is overridden. A
        // reader who sees a high aggregate beside RED is reading a CRITICAL
        // breach, and that is the one combination the two figures cannot
        // otherwise express.
        if (critical_breaches > 0) {
            outcome.verdict = EthicalMatrix.Verdict.RED;
        } else {
            outcome.verdict = matrix.computeVerdict(
                uint8(outcome.aggregate_score)
            );
        }
    }

    // ─────────────────────────────────────────────────────────────
    // VIEW FUNCTIONS
    // ─────────────────────────────────────────────────────────────

    /// @notice Preview verdict without writing to state (for off-chain simulation)
    function previewVerdict(
        uint8[] memory asilomar_ids,
        uint8[] memory tdsh_ids,
        uint8[] memory ematch_scores
    ) external view returns (
        EthicalMatrix.Verdict verdict,
        uint256 aggregate_score,
        uint256 cells_activated
    ) {
        require(
            asilomar_ids.length == tdsh_ids.length &&
            tdsh_ids.length == ematch_scores.length,
            "Array length mismatch"
        );

        uint256 weighted_sum = 0;
        uint256 weight_total = 0;
        uint256 cells_active = 0;
        uint256 critical_breaches = 0;

        for (uint i = 0; i < asilomar_ids.length; i++) {
            // The same filter as _computeSide, so that a preview and the
            // binding computation can never disagree — the CRITICAL override
            // and the undetermined state are mirrored here for the same
            // reason. This function previews one side at a time; the binding
            // call takes both. Nothing is emitted here: it writes no state and
            // keeps no record.
            if (
                asilomar_ids[i] < 1 || asilomar_ids[i] > 23 ||
                tdsh_ids[i]     < 1 || tdsh_ids[i]     > 32
            ) continue;
            if (ematch_scores[i] > 100) continue;

            uint8 weight = matrix.getCellWeight(asilomar_ids[i], tdsh_ids[i]);
            if (weight == 0) continue;
            weighted_sum += uint256(ematch_scores[i]) * uint256(weight);
            weight_total += uint256(weight);
            cells_active++;

            if (
                weight == 3 &&
                matrix.computeVerdict(ematch_scores[i]) ==
                    EthicalMatrix.Verdict.RED
            ) {
                critical_breaches++;
            }
        }

        if (weight_total == 0) {
            return (EthicalMatrix.Verdict.UNDETERMINED, 0, 0);
        }

        aggregate_score  = weighted_sum / weight_total;
        verdict          = critical_breaches > 0
            ? EthicalMatrix.Verdict.RED
            : matrix.computeVerdict(uint8(aggregate_score));
        cells_activated  = cells_active;
    }
}