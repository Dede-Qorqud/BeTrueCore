// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/IBeTrueCore.sol";
import "../src/BeTrueCoreCore.sol";
import "../src/EthicalMatrix.sol";
import "../src/HarmonyAgent.sol";
import "../src/VWUEngine.sol";

/// @title AssertionsTest
/// @notice Tests of architectural promises, not of arithmetic.
/// @dev Run with: forge test --match-path test/Assertions.t.sol -v
///
/// Every test here is named as a sentence, and the sentence is a promise this
/// architecture makes in its documents. A failure means the code stopped
/// keeping that promise — not that a number came out wrong.
///
/// Why this file exists beside BeTrueCore.t.sol. That file checks mechanics:
/// whether a call succeeds, whether a figure adds up. Mechanics passed through
/// the whole of stage A while a participant's address sat in an event, a
/// getter returned another person's record, and the non-burnable floor was a
/// hundredth of its published value. None of it surfaced before the audit,
/// because nothing in the suite was looking for it. These tests look for it.
///
/// What they cannot do. Promises kept by the absence of something — no getter
/// for another participant's record, no majority flag reaching the verdict —
/// are kept by the compiler: writing the call would fail to build, so there is
/// nothing here to assert. Those are listed at the end of this file as the
/// promises the suite does not cover, rather than left to look covered.

contract AssertionsTest is Test {

    EthicalMatrix  public matrix;
    HarmonyAgent   public harmony;
    VWUEngine      public engine;
    BeTrueCoreCore public core;

    /// @dev A second engine whose coordinator is this test contract, so that
    ///      updateVWU can be called directly. The engine in the deployed
    ///      package is reachable only through BeTrueCoreCore, and the floor and
    ///      the cap are properties of the engine itself.
    VWUEngine public engineDirect;

    address deployer    = address(0x1);
    address coordinator = address(0x2);
    address outsider    = address(0xBAD);
    address successor   = address(0x5);

    bytes32 constant IDENTITY_1 = keccak256("test identity commitment 1");
    bytes32 constant IDENTITY_2 = keccak256("test identity commitment 2");

    uint256 constant DURATION = 1 days;

    function setUp() public {
        vm.startPrank(deployer);

        matrix  = new EthicalMatrix();
        engine  = new VWUEngine(coordinator);
        harmony = new HarmonyAgent(address(matrix));
        core    = new BeTrueCoreCore(
            coordinator,
            address(matrix),
            address(harmony),
            address(engine)
        );

        matrix.setHarmonyAgent(address(harmony));
        engine.setCoordinator(address(core));

        _populateCells();

        vm.stopPrank();

        engineDirect = new VWUEngine(address(this));
    }

    /// @dev Four cells, enough to exercise the bands: one CRITICAL and three
    ///      HIGH. The map assigns T01-T08 to the Analyst, T09-T16 to the
    ///      Strategist and T17-T32 to the Sentinel; the agent of a cell plays
    ///      no part in aggregation, so these follow that split only to stay
    ///      consistent with the published map.
    function _populateCells() internal {
        uint8[] memory a = new uint8[](4);
        uint8[] memory t = new uint8[](4);
        EthicalMatrix.CellState[] memory p = new EthicalMatrix.CellState[](4);
        EthicalMatrix.AgentType[] memory g = new EthicalMatrix.AgentType[](4);

        a[0] = 1;  t[0] = 1;  p[0] = EthicalMatrix.CellState.CRITICAL;      g[0] = EthicalMatrix.AgentType.ANALYST;
        a[1] = 2;  t[1] = 2;  p[1] = EthicalMatrix.CellState.HIGH;          g[1] = EthicalMatrix.AgentType.ANALYST;
        a[2] = 3;  t[2] = 10; p[2] = EthicalMatrix.CellState.HIGH;          g[2] = EthicalMatrix.AgentType.STRATEGIST;
        a[3] = 4;  t[3] = 20; p[3] = EthicalMatrix.CellState.HIGH;          g[3] = EthicalMatrix.AgentType.SENTINEL;

        matrix.populateCells(a, t, p, g);
    }

    // ══════════════════════════════════════════════════════════════════════
    // THE WEIGHT OF A PARTICIPANT
    // ══════════════════════════════════════════════════════════════════════

    /// The non-burnable floor is one hundred — one whole VWU at the ×100 scale.
    /// Published as a floor of 1.00 VWU; a value of 1 would make it 0.01.
    function test_the_non_burnable_floor_is_one_hundred() public view {
        assertEq(engine.VWU_BASE(), 100, "the published floor is 1.00 VWU, which is 100 at this scale");
    }

    /// A rating never falls below the non-burnable floor, whatever is submitted.
    function test_a_rating_never_falls_below_the_non_burnable_floor() public {
        engineDirect.initializeParticipant(address(0x11));

        int256 applied = engineDirect.updateVWU(VWUEngine.SessionResult({
            participant:       address(0x11),
            delta:             -1_000_000,
            session_timestamp: block.timestamp
        }));

        assertEq(applied, int256(0), "a participant at the floor loses nothing");
    }

    /// A rating never exceeds the cap, whatever is submitted.
    function test_a_rating_never_exceeds_the_cap() public {
        engineDirect.initializeParticipant(address(0x12));

        int256 first = engineDirect.updateVWU(VWUEngine.SessionResult({
            participant:       address(0x12),
            delta:             1_000_000,
            session_timestamp: block.timestamp
        }));

        int256 second = engineDirect.updateVWU(VWUEngine.SessionResult({
            participant:       address(0x12),
            delta:             1_000_000,
            session_timestamp: block.timestamp
        }));

        assertGt(first, int256(0), "the first credit moves the rating");
        assertEq(second, int256(0), "a rating at the cap takes nothing further");
    }

    /// Silence never reduces a rating: an absent participant is credited zero
    /// and keeps every point. Absence freezes a rating; it never lowers it.
    function test_silence_never_reduces_a_rating() public {
        engineDirect.initializeParticipant(address(0x13));

        for (uint256 i = 0; i < 5; i++) {
            int256 applied = engineDirect.updateVWU(VWUEngine.SessionResult({
                participant:       address(0x13),
                delta:             0,
                session_timestamp: block.timestamp + i
            }));
            assertEq(applied, int256(0), "a silent session changes nothing");
        }
    }

    /// The rational filter is the only mechanism that lowers a rating, and it
    /// is recorded whenever it is applied — including where it could take
    /// nothing, because a participant was already at the floor.
    function test_the_rational_filter_is_recorded_even_when_it_takes_nothing() public {
        engineDirect.initializeParticipant(address(0x14));

        uint256 before_ = engineDirect.filterTotal();

        engineDirect.updateVWU(VWUEngine.SessionResult({
            participant:       address(0x14),
            delta:             -50,
            session_timestamp: block.timestamp
        }));

        assertEq(engineDirect.filterTotal(), before_ + 1, "the filter is recorded, not silently dropped");
    }

    // ══════════════════════════════════════════════════════════════════════
    // THE LOG NEVER NAMES A PARTICIPANT
    // ══════════════════════════════════════════════════════════════════════

    /// No event emitted by a registration carries the identity commitment or
    /// the address derived from it — not in a topic, not in the data.
    function test_the_log_never_names_a_participant_on_registration() public {
        vm.recordLogs();

        vm.prank(outsider);
        core.register(IDENTITY_1, "");

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertGt(entries.length, 0, "a registration emits something");

        bytes32 derived = bytes32(uint256(uint160(address(uint160(uint256(IDENTITY_1))))));

        for (uint256 i = 0; i < entries.length; i++) {
            for (uint256 j = 1; j < entries[i].topics.length; j++) {
                assertTrue(entries[i].topics[j] != IDENTITY_1, "no topic carries the commitment");
                assertTrue(entries[i].topics[j] != derived,    "no topic carries the derived address");
            }
            assertFalse(_contains(entries[i].data, IDENTITY_1), "no data field carries the commitment");
            assertFalse(_contains(entries[i].data, derived),    "no data field carries the derived address");
        }
    }

    /// A recorded choice carries the session and nothing else — no participant,
    /// no nullifier, no ciphertext.
    function test_a_recorded_choice_carries_nothing_but_the_session() public {
        vm.prank(coordinator);
        uint256 session_id = core.openSession(keccak256("dilemma"), DURATION);

        vm.recordLogs();
        vm.prank(outsider);
        core.submitChoice(session_id, hex"deadbeef", keccak256("nullifier"));

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 1, "one event per recorded choice");
        assertEq(entries[0].topics.length, 2, "the session id and nothing further");
        assertEq(entries[0].topics[0], keccak256("ChoiceRecorded(uint256)"));
        assertEq(uint256(entries[0].topics[1]), session_id);
        assertEq(entries[0].data.length, 0, "no data field at all");
    }

    /// No one but the engine's coordinator contract can ask whether an address
    /// is registered. A participant cannot read another participant's record.
    function test_no_one_outside_the_protocol_can_read_a_registration() public {
        vm.prank(outsider);
        vm.expectRevert(VWUEngine.NotCoordinator.selector);
        engine.isRegistered(address(uint160(uint256(IDENTITY_1))));
    }

    // ══════════════════════════════════════════════════════════════════════
    // THE ROSTER, AND THE THREE ROWS THAT MUST ACCOUNT FOR IT
    // ══════════════════════════════════════════════════════════════════════

    /// The roster is fixed when a session opens and does not move afterwards.
    /// Whoever registers while a session is open joins from the next one.
    function test_the_roster_is_fixed_when_a_session_opens() public {
        vm.prank(outsider);
        core.register(IDENTITY_1, "");

        vm.prank(coordinator);
        uint256 session_id = core.openSession(keccak256("dilemma"), DURATION);

        vm.prank(outsider);
        core.register(IDENTITY_2, "");

        IBeTrueCore.Session memory s = core.getSession(session_id);
        assertEq(s.roster_count, 1, "the roster does not grow once the session is open");
        assertEq(core.getParticipantCount(), 2, "the registry does grow");
    }

    /// A session carries no verdict before it has been judged — not GREEN.
    function test_a_session_opens_undetermined_not_green() public {
        vm.prank(coordinator);
        uint256 session_id = core.openSession(keccak256("dilemma"), DURATION);

        IBeTrueCore.Session memory s = core.getSession(session_id);
        assertEq(uint256(s.verdict_option_a), uint256(IBeTrueCore.Verdict.UNDETERMINED));
        assertEq(uint256(s.verdict_option_b), uint256(IBeTrueCore.Verdict.UNDETERMINED));
    }

    /// The three rows of a result must account for the roster by people.
    /// A result that drops a participant is refused.
    function test_a_result_must_account_for_the_roster_by_people() public {
        (uint256 session_id, ) = _openWithOneParticipant();
        vm.warp(block.timestamp + DURATION + 1);

        IBeTrueCore.SessionResult memory r = _result(session_id, 0, 0, 0, 0, 0, 0);

        vm.prank(coordinator);
        vm.expectRevert("Rows do not account for the roster");
        core.finalizeSession(session_id, r);
    }

    /// The three rows must account for the roster by weight as well.
    function test_a_result_must_account_for_the_roster_by_weight() public {
        (uint256 session_id, uint256 roster_weight) = _openWithOneParticipant();
        vm.warp(block.timestamp + DURATION + 1);

        // Counts add up; weights do not.
        IBeTrueCore.SessionResult memory r =
            _result(session_id, 1, roster_weight + 1, 0, 0, 0, 0);

        vm.prank(coordinator);
        vm.expectRevert("Weights do not account for the roster");
        core.finalizeSession(session_id, r);
    }

    /// Silence is a row of its own, and a result consisting only of silence is
    /// valid: where no one chose, the Panorama shows exactly that.
    function test_a_session_where_everyone_stayed_silent_is_a_valid_result() public {
        (uint256 session_id, uint256 roster_weight) = _openWithOneParticipant();
        vm.warp(block.timestamp + DURATION + 1);

        IBeTrueCore.SessionResult memory r =
            _result(session_id, 0, 0, 0, 0, 1, roster_weight);

        vm.prank(coordinator);
        core.finalizeSession(session_id, r);

        IBeTrueCore.SessionResult memory stored = core.getSessionResult(session_id);
        assertEq(stored.count_silent, 1, "silence is recorded as silence");
    }

    /// Every participant fixed for a session gets a record, silence included.
    /// A short list leaves someone without one and is refused.
    function test_participation_must_cover_the_whole_roster() public {
        (uint256 session_id, uint256 roster_weight) = _openWithOneParticipant();
        vm.warp(block.timestamp + DURATION + 1);

        vm.prank(coordinator);
        core.finalizeSession(session_id, _result(session_id, 0, 0, 0, 0, 1, roster_weight));

        bytes32[] memory commitments = new bytes32[](0);
        int256[]  memory deltas      = new int256[](0);

        vm.prank(coordinator);
        vm.expectRevert("List does not cover the roster");
        core.applySessionParticipation(session_id, commitments, deltas);
    }

    // ══════════════════════════════════════════════════════════════════════
    // THE LOCK, AND WHAT CANNOT BE CHANGED AFTER IT
    // ══════════════════════════════════════════════════════════════════════

    /// A session cannot be finalized before its time lock is reached.
    function test_a_session_cannot_be_finalized_before_the_time_lock() public {
        (uint256 session_id, uint256 roster_weight) = _openWithOneParticipant();

        vm.prank(coordinator);
        vm.expectRevert("Time lock not reached");
        core.finalizeSession(session_id, _result(session_id, 0, 0, 0, 0, 1, roster_weight));
    }

    /// A result is immutable once fixed: a finalized session cannot be
    /// finalized again.
    function test_a_finalized_session_cannot_be_finalized_again() public {
        (uint256 session_id, uint256 roster_weight) = _openWithOneParticipant();
        vm.warp(block.timestamp + DURATION + 1);

        IBeTrueCore.SessionResult memory r = _result(session_id, 0, 0, 0, 0, 1, roster_weight);

        vm.startPrank(coordinator);
        core.finalizeSession(session_id, r);
        vm.expectRevert("Already finalized");
        core.finalizeSession(session_id, r);
        vm.stopPrank();
    }

    /// A nullifier cannot be spent twice: one entry per participant per session.
    function test_a_nullifier_cannot_be_spent_twice() public {
        vm.prank(coordinator);
        uint256 session_id = core.openSession(keccak256("dilemma"), DURATION);

        bytes32 nullifier = keccak256("nullifier");

        vm.prank(outsider);
        core.submitChoice(session_id, hex"01", nullifier);

        vm.prank(outsider);
        vm.expectRevert("Nullifier already used");
        core.submitChoice(session_id, hex"02", nullifier);
    }

    // ══════════════════════════════════════════════════════════════════════
    // THE MAP MEASURES — THE VERDICT IS NOT THE AGENT'S
    // ══════════════════════════════════════════════════════════════════════

    /// A breach of a CRITICAL cell forces RED whatever the weighted mean says.
    /// A safety-critical intersection is not a quantity to be averaged away.
    function test_a_critical_breach_forces_red_whatever_the_mean() public view {
        uint8[] memory a = new uint8[](4);
        uint8[] memory t = new uint8[](4);
        uint8[] memory s = new uint8[](4);

        a[0] = 1; t[0] = 1;  s[0] = 10;   // CRITICAL, in the RED band
        a[1] = 2; t[1] = 2;  s[1] = 100;  // HIGH, clean
        a[2] = 3; t[2] = 10; s[2] = 100;  // HIGH, clean
        a[3] = 4; t[3] = 20; s[3] = 100;  // HIGH, clean

        (EthicalMatrix.Verdict verdict, uint256 mean, ) =
            harmony.previewVerdict(a, t, s);

        assertGe(mean, 70, "the weighted mean alone would read GREEN");
        assertEq(uint256(verdict), uint256(EthicalMatrix.Verdict.RED),
            "a breached CRITICAL cell forces RED");
    }

    /// Where nothing could be measured the answer is UNDETERMINED, never GREEN.
    /// GREEN would publish "no violations found" where the truth is "nothing
    /// could be read".
    function test_nothing_measurable_is_undetermined_not_green() public view {
        uint8[] memory empty = new uint8[](0);

        (EthicalMatrix.Verdict verdict, uint256 mean, uint256 cells) =
            harmony.previewVerdict(empty, empty, empty);

        assertEq(uint256(verdict), uint256(EthicalMatrix.Verdict.UNDETERMINED));
        assertEq(mean, 0, "no figure is truthful here");
        assertEq(cells, 0);
    }

    /// UNDETERMINED is the zero value of the enum, so an unset verdict reads as
    /// "not measured" rather than as a breach.
    function test_an_unset_verdict_reads_as_undetermined() public pure {
        assertEq(uint256(EthicalMatrix.Verdict.UNDETERMINED), 0, "UNDETERMINED stands first");
        assertEq(uint256(IBeTrueCore.Verdict.UNDETERMINED),   0, "and in the archive interface too");
    }

    /// The two Verdict enums carry the same values in the same order: a verdict
    /// crosses from the matrix into the permanent archive through the interface.
    function test_the_two_verdict_enums_agree() public pure {
        assertEq(uint256(EthicalMatrix.Verdict.RED),    uint256(IBeTrueCore.Verdict.RED));
        assertEq(uint256(EthicalMatrix.Verdict.YELLOW), uint256(IBeTrueCore.Verdict.YELLOW));
        assertEq(uint256(EthicalMatrix.Verdict.GREEN),  uint256(IBeTrueCore.Verdict.GREEN));
    }

    /// Nothing but the connected Harmony Agent can write to the audit trail.
    function test_only_the_harmony_agent_can_write_the_audit_trail() public {
        vm.prank(outsider);
        vm.expectRevert("Only HarmonyAgent");
        matrix.triggerCell(1, 1, 1, 50);
    }

    /// A cell outside the 23 x 32 matrix is refused rather than read as empty.
    function test_a_cell_outside_the_matrix_is_refused() public {
        vm.expectRevert("Asilomar id out of range");
        matrix.getCellWeight(24, 1);

        vm.expectRevert("TDSH id out of range");
        matrix.getCellWeight(1, 33);
    }

    // ══════════════════════════════════════════════════════════════════════
    // ROLES — NO ROLE STANDS ABOVE A PARTICIPANT, AND NONE PASSES IN SILENCE
    // ══════════════════════════════════════════════════════════════════════

    /// Opening a session is the coordinator's act, and the coordinator is the
    /// community. The address that deployed the contract cannot open one.
    function test_only_the_coordinator_can_open_a_session() public {
        vm.prank(deployer);
        vm.expectRevert("Only anti-collusion coordinator");
        core.openSession(keccak256("dilemma"), DURATION);

        vm.prank(outsider);
        vm.expectRevert("Only anti-collusion coordinator");
        core.openSession(keccak256("dilemma"), DURATION);
    }

    /// Crediting participation is the coordinator's act alone.
    function test_only_the_coordinator_can_credit_participation() public {
        (uint256 session_id, uint256 roster_weight) = _openWithOneParticipant();
        vm.warp(block.timestamp + DURATION + 1);

        vm.prank(coordinator);
        core.finalizeSession(session_id, _result(session_id, 0, 0, 0, 0, 1, roster_weight));

        bytes32[] memory commitments = new bytes32[](1);
        int256[]  memory deltas      = new int256[](1);
        commitments[0] = IDENTITY_1;
        deltas[0]      = 10;

        vm.prank(outsider);
        vm.expectRevert("Only anti-collusion coordinator");
        core.applySessionParticipation(session_id, commitments, deltas);
    }

    /// A role never passes in one step. Naming a successor moves nothing until
    /// the successor takes the role by its own call.
    function test_a_role_never_passes_in_one_step() public {
        vm.prank(coordinator);
        core.proposeCoordinator(successor);

        assertEq(core.maciCoordinator(), coordinator, "naming a successor moves nothing");

        vm.prank(outsider);
        vm.expectRevert("Not the proposed coordinator");
        core.acceptCoordinator();

        vm.prank(successor);
        core.acceptCoordinator();

        assertEq(core.maciCoordinator(), successor, "the successor took the role by its own call");
    }

    /// A participation credited to a commitment nobody registered is refused.
    function test_an_unregistered_commitment_cannot_be_credited() public {
        (uint256 session_id, uint256 roster_weight) = _openWithOneParticipant();
        vm.warp(block.timestamp + DURATION + 1);

        vm.prank(coordinator);
        core.finalizeSession(session_id, _result(session_id, 0, 0, 0, 0, 1, roster_weight));

        bytes32[] memory commitments = new bytes32[](1);
        int256[]  memory deltas      = new int256[](1);
        commitments[0] = keccak256("never registered");
        deltas[0]      = 10;

        vm.prank(coordinator);
        vm.expectRevert("Participant not registered");
        core.applySessionParticipation(session_id, commitments, deltas);
    }

    // ══════════════════════════════════════════════════════════════════════
    // HELPERS
    // ══════════════════════════════════════════════════════════════════════

    function _openWithOneParticipant()
        internal
        returns (uint256 session_id, uint256 roster_weight)
    {
        vm.prank(outsider);
        core.register(IDENTITY_1, "");

        vm.prank(coordinator);
        session_id = core.openSession(keccak256("dilemma"), DURATION);

        roster_weight = core.getSession(session_id).roster_weight;
    }

    function _result(
        uint256 session_id,
        uint256 count_a,
        uint256 weight_a,
        uint256 count_b,
        uint256 weight_b,
        uint256 count_silent,
        uint256 weight_silent
    ) internal pure returns (IBeTrueCore.SessionResult memory) {
        return IBeTrueCore.SessionResult({
            session_id:          session_id,
            count_option_a:      count_a,
            total_weight_a:      weight_a,
            count_option_b:      count_b,
            total_weight_b:      weight_b,
            count_silent:        count_silent,
            total_weight_silent: weight_silent,
            zk_proof_hash:       keccak256("proof"),
            verdict_option_a:    IBeTrueCore.Verdict.UNDETERMINED,
            verdict_option_b:    IBeTrueCore.Verdict.UNDETERMINED
        });
    }

    /// @dev Whether a 32-byte value appears anywhere in an event's data field,
    ///      at any offset rather than only at a word boundary.
    function _contains(bytes memory haystack, bytes32 needle)
        internal pure returns (bool)
    {
        if (haystack.length < 32) return false;
        for (uint256 i = 0; i + 32 <= haystack.length; i++) {
            bool same = true;
            for (uint256 j = 0; j < 32; j++) {
                if (haystack[i + j] != needle[j]) { same = false; break; }
            }
            if (same) return true;
        }
        return false;
    }

    // ══════════════════════════════════════════════════════════════════════
    // PROMISES THIS SUITE DOES NOT COVER
    //
    // Listed so that a green run is not read as more than it is.
    //
    //  - No getter returns another participant's record. Kept by the compiler:
    //    the functions do not exist, so there is no call to assert against.
    //    The nearest check here is the registration read, which is gated.
    //  - No majority flag reaches the verdict. Kept by the signature of
    //    computeFinalVerdict, which has no parameter for it.
    //  - Silence receives no colour. Kept by the shape of Session, which holds
    //    a verdict per option and none for silence.
    //  - The participant does not see the distribution while choosing. Kept by
    //    the Lit Protocol time lock, off-chain; nothing on-chain to assert.
    //  - The set of participants is the set fixed for the session. Not kept
    //    anywhere: the count is checked, the membership is not. That is the
    //    set-equality primitive recorded as not established.
    //  - The chain's recomputation binds the verdict. Not kept: no contract
    //    calls computeFinalVerdict, and finalizeSession compares the submitted
    //    verdicts with nothing. A test asserting it would fail, and correctly.
    // ══════════════════════════════════════════════════════════════════════
}
