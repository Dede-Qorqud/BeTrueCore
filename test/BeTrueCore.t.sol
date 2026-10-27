// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/IBeTrueCore.sol";
import "../src/BeTrueCoreCore.sol";
import "../src/EthicalMatrix.sol";
import "../src/HarmonyAgent.sol";
import "../src/VWUEngine.sol";

/// @title BeTrueCoreTest
/// @notice Foundry unit tests for BeTrueCore Developer Package v0.3
/// @dev Run with: forge test -v
///      BeTrueCore Developer Package v0.3
///      github.com/Dede-Qorqud/BeTrueCore

contract BeTrueCoreTest is Test {

    // ─────────────────────────────────────────────────────────────
    // CONTRACTS
    // ─────────────────────────────────────────────────────────────

    EthicalMatrix  public matrix;
    HarmonyAgent   public harmony;
    VWUEngine      public vwuEngine;
    BeTrueCoreCore public core;

    // ─────────────────────────────────────────────────────────────
    // TEST ADDRESSES
    // ─────────────────────────────────────────────────────────────

    address deployer     = address(0x1);
    address coordinator  = address(0x2);
    address participant  = address(0x3);
    address participant2 = address(0x4);

    // ─────────────────────────────────────────────────────────────
    // TEST IDENTITY COMMITMENTS
    // ─────────────────────────────────────────────────────────────
    // Deliberately NOT derived from any address: a commitment that anyone
    // can recompute from an address is not a pseudonym.

    bytes32 constant IDENTITY_1 = keccak256("test identity commitment 1");
    bytes32 constant IDENTITY_2 = keccak256("test identity commitment 2");

    // ─────────────────────────────────────────────────────────────
    // SETUP
    // ─────────────────────────────────────────────────────────────

    function setUp() public {
        vm.startPrank(deployer);

        // Deploy contracts in order
        matrix    = new EthicalMatrix();
        vwuEngine = new VWUEngine(coordinator);
        harmony   = new HarmonyAgent(address(matrix));
        core      = new BeTrueCoreCore(
            coordinator,
            address(matrix),
            address(harmony),
            address(vwuEngine)
        );

        // Register HarmonyAgent as the only writer of audit events
        matrix.setHarmonyAgent(address(harmony));

        // The engine's coordinator is the core contract itself. The
        // anti-collusion coordinator address talks to core, never to the engine.
        vwuEngine.setCoordinator(address(core));

        // Populate a subset of the 736-point matrix for testing
        _populateTestMatrix();

        vm.stopPrank();
    }

    /// @dev Populate the canonical nine cells of the 736-point map — three per
    ///      agent type. The map assigns every TDSH parameter to exactly one
    ///      agent: T01–T08 to the Analyst, T09–T16 to the Strategist, T17–T32
    ///      to the Sentinel. A canonical cell of an agent therefore lies in
    ///      that agent's own band, and all nine below are CRITICAL in the map.
    function _populateTestMatrix() internal {
        uint8[]  memory a_ids      = new uint8[](9);
        uint8[]  memory t_ids      = new uint8[](9);
        EthicalMatrix.CellState[] memory priorities = new EthicalMatrix.CellState[](9);
        EthicalMatrix.AgentType[] memory agents     = new EthicalMatrix.AgentType[](9);

        // Analyst canonical cells — T01–T08
        a_ids[0] = 6;  t_ids[0] = 2;  priorities[0] = EthicalMatrix.CellState.CRITICAL; agents[0] = EthicalMatrix.AgentType.ANALYST;   // A06×T02
        a_ids[1] = 12; t_ids[1] = 4;  priorities[1] = EthicalMatrix.CellState.CRITICAL; agents[1] = EthicalMatrix.AgentType.ANALYST;   // A12×T04
        a_ids[2] = 10; t_ids[2] = 8;  priorities[2] = EthicalMatrix.CellState.CRITICAL; agents[2] = EthicalMatrix.AgentType.ANALYST;   // A10×T08

        // Strategist canonical cells — T09–T16
        a_ids[3] = 17; t_ids[3] = 16; priorities[3] = EthicalMatrix.CellState.CRITICAL; agents[3] = EthicalMatrix.AgentType.STRATEGIST; // A17×T16
        a_ids[4] = 16; t_ids[4] = 14; priorities[4] = EthicalMatrix.CellState.CRITICAL; agents[4] = EthicalMatrix.AgentType.STRATEGIST; // A16×T14
        a_ids[5] = 14; t_ids[5] = 9;  priorities[5] = EthicalMatrix.CellState.CRITICAL; agents[5] = EthicalMatrix.AgentType.STRATEGIST; // A14×T09

        // Sentinel canonical cells — T17–T32
        a_ids[6] = 18; t_ids[6] = 29; priorities[6] = EthicalMatrix.CellState.CRITICAL; agents[6] = EthicalMatrix.AgentType.SENTINEL;  // A18×T29
        a_ids[7] = 19; t_ids[7] = 26; priorities[7] = EthicalMatrix.CellState.CRITICAL; agents[7] = EthicalMatrix.AgentType.SENTINEL;  // A19×T26
        a_ids[8] = 11; t_ids[8] = 30; priorities[8] = EthicalMatrix.CellState.CRITICAL; agents[8] = EthicalMatrix.AgentType.SENTINEL;  // A11×T30

        matrix.populateCells(a_ids, t_ids, priorities, agents);
    }

    // ─────────────────────────────────────────────────────────────
    // ETHICAL MATRIX TESTS
    // ─────────────────────────────────────────────────────────────

    function test_CellWeight_Critical() public {
        uint8 weight = matrix.getCellWeight(6, 2); // A06×T02 = CRITICAL
        assertEq(weight, 3, "CRITICAL cell should have weight 3");
    }

    function test_CellWeight_Unset() public {
        uint8 weight = matrix.getCellWeight(1, 1); // unpopulated = SUPERPOSITION
        assertEq(weight, 0, "Unpopulated cell should have weight 0 (SUPERPOSITION)");
    }

    function test_ComputeVerdict_Red() public {
        EthicalMatrix.Verdict v = matrix.computeVerdict(30); // < 40
        assertEq(uint8(v), uint8(EthicalMatrix.Verdict.RED), "Score 30 should be RED");
    }

    function test_ComputeVerdict_Yellow() public {
        EthicalMatrix.Verdict v = matrix.computeVerdict(55); // 40–69
        assertEq(uint8(v), uint8(EthicalMatrix.Verdict.YELLOW), "Score 55 should be YELLOW");
    }

    function test_ComputeVerdict_Green() public {
        EthicalMatrix.Verdict v = matrix.computeVerdict(80); // >= 70
        assertEq(uint8(v), uint8(EthicalMatrix.Verdict.GREEN), "Score 80 should be GREEN");
    }

    function test_ComputeVerdict_Boundary_40() public {
        EthicalMatrix.Verdict v = matrix.computeVerdict(40);
        assertEq(uint8(v), uint8(EthicalMatrix.Verdict.YELLOW), "Score 40 should be YELLOW (boundary)");
    }

    function test_ComputeVerdict_Boundary_70() public {
        EthicalMatrix.Verdict v = matrix.computeVerdict(70);
        assertEq(uint8(v), uint8(EthicalMatrix.Verdict.GREEN), "Score 70 should be GREEN (boundary)");
    }

    function test_ComputeVerdict_ZeroIsMeasuredNotAbsent() public {
        // A score of zero is a measurement whose result is zero — not the
        // absence of a measurement. It must be RED, never UNDETERMINED and
        // never GREEN.
        EthicalMatrix.Verdict v = matrix.computeVerdict(0);
        assertEq(uint8(v), uint8(EthicalMatrix.Verdict.RED), "Score 0 should be RED");
        assertTrue(
            uint8(v) != uint8(EthicalMatrix.Verdict.UNDETERMINED),
            "A measured zero must not be reported as no measurement"
        );
    }

    function test_CellAgent_Strategist() public {
        EthicalMatrix.AgentType agent = matrix.getCellAgent(17, 16); // A17×T16
        assertEq(uint8(agent), uint8(EthicalMatrix.AgentType.STRATEGIST), "A17xT16 should be STRATEGIST");
    }

    function test_CellAgent_Analyst() public {
        EthicalMatrix.AgentType agent = matrix.getCellAgent(6, 2); // A06×T02
        assertEq(uint8(agent), uint8(EthicalMatrix.AgentType.ANALYST), "A06xT02 should be ANALYST");
    }

    function test_CellAgent_Sentinel() public {
        EthicalMatrix.AgentType agent = matrix.getCellAgent(18, 29); // A18×T29
        assertEq(uint8(agent), uint8(EthicalMatrix.AgentType.SENTINEL), "A18xT29 should be SENTINEL");
    }

    // ─────────────────────────────────────────────────────────────
    // HARMONY AGENT TESTS
    // ─────────────────────────────────────────────────────────────

    function test_HarmonyAgent_AllGreen() public {
        uint8[] memory a_ids  = new uint8[](3);
        uint8[] memory t_ids  = new uint8[](3);
        uint8[] memory scores = new uint8[](3);

        a_ids[0] = 6;  t_ids[0] = 2;  scores[0] = 90; // A06×T02 CRITICAL weight=3 score=90
        a_ids[1] = 12; t_ids[1] = 4;  scores[1] = 85; // A12×T04 CRITICAL weight=3 score=85
        a_ids[2] = 10; t_ids[2] = 8;  scores[2] = 80; // A10×T08 CRITICAL weight=3 score=80

        // Expected: (90×3 + 85×3 + 80×3) / (3+3+3) = 765/9 = 85 → GREEN
        (EthicalMatrix.Verdict verdict, uint256 score, ) = harmony.previewVerdict(a_ids, t_ids, scores);
        assertEq(uint8(verdict), uint8(EthicalMatrix.Verdict.GREEN), "All high scores should be GREEN");
        assertEq(score, 85, "Aggregate score should be 85");
    }

    function test_HarmonyAgent_CriticalRed() public {
        uint8[] memory a_ids  = new uint8[](2);
        uint8[] memory t_ids  = new uint8[](2);
        uint8[] memory scores = new uint8[](2);

        a_ids[0] = 6;  t_ids[0] = 2;  scores[0] = 10; // CRITICAL weight=3 score=10 → RED
        a_ids[1] = 12; t_ids[1] = 4;  scores[1] = 80; // CRITICAL weight=3 score=80 → GREEN

        // The aggregate is still computed: (10×3 + 80×3) / 6 = 270/6 = 45, which
        // on its own would read YELLOW. It does not decide here. A CRITICAL cell
        // is a direct, safety-critical intersection, and a breach of one is not
        // a quantity to be averaged away by sound cells beside it: a CRITICAL
        // cell whose own score falls in the RED band forces this side's verdict
        // to RED, whatever the mean. The score and the verdict are therefore
        // checked separately — the arithmetic is not the finding.
        (EthicalMatrix.Verdict verdict, uint256 score, ) = harmony.previewVerdict(a_ids, t_ids, scores);
        assertEq(uint8(verdict), uint8(EthicalMatrix.Verdict.RED), "A breached CRITICAL cell forces RED");
        assertEq(score, 45, "Aggregate score should be 45");
    }

    function test_HarmonyAgent_NoActiveCells() public {
        uint8[] memory a_ids  = new uint8[](1);
        uint8[] memory t_ids  = new uint8[](1);
        uint8[] memory scores = new uint8[](1);

        a_ids[0] = 1; t_ids[0] = 1; scores[0] = 50; // unpopulated = SUPERPOSITION weight=0

        // SUPERPOSITION cells are excluded, so no cell was measured. That is
        // reported as UNDETERMINED. Green is a finding, never a default: a
        // verdict of GREEN here would state that something was measured and
        // found sound, which is false.
        (EthicalMatrix.Verdict verdict, uint256 score, ) = harmony.previewVerdict(a_ids, t_ids, scores);
        assertEq(
            uint8(verdict),
            uint8(EthicalMatrix.Verdict.UNDETERMINED),
            "No active cells -> UNDETERMINED, not GREEN"
        );
        assertEq(score, 0, "No active cells -> no score");
    }

    function test_HarmonyAgent_SameMeasureForBothSides() public {
        // One measure for both sides of a dilemma — the same map, the same
        // thresholds — and a colour of its own for each side. Equal
        // application means one measure, not one colour.
        uint8[] memory a_ids  = new uint8[](1);
        uint8[] memory t_ids  = new uint8[](1);
        uint8[] memory side_a = new uint8[](1);
        uint8[] memory side_b = new uint8[](1);

        a_ids[0] = 6; t_ids[0] = 2;   // A06xT02, CRITICAL, weight 3
        side_a[0] = 75;               // >= 70 -> GREEN
        side_b[0] = 30;               // <  40 -> RED

        (EthicalMatrix.Verdict verdict_a, , ) = harmony.previewVerdict(a_ids, t_ids, side_a);
        (EthicalMatrix.Verdict verdict_b, , ) = harmony.previewVerdict(a_ids, t_ids, side_b);

        assertEq(uint8(verdict_a), uint8(EthicalMatrix.Verdict.GREEN), "Side A at 75 should be GREEN");
        assertEq(uint8(verdict_b), uint8(EthicalMatrix.Verdict.RED), "Side B at 30 should be RED");
        assertTrue(
            uint8(verdict_a) != uint8(verdict_b),
            "Each side carries its own colour, not one colour for the whole session"
        );

        // And the measure itself does not depend on which side it is applied
        // to: identical input, identical verdict.
        (EthicalMatrix.Verdict repeat_a, , ) = harmony.previewVerdict(a_ids, t_ids, side_a);
        assertEq(uint8(repeat_a), uint8(verdict_a), "The same input must yield the same verdict on either side");
    }

    // ─────────────────────────────────────────────────────────────
    // VWU ENGINE TESTS
    // ─────────────────────────────────────────────────────────────

    /// @dev Helper: one computed session contribution.
    ///      The engine receives the result of the calculation, never its
    ///      inputs: completed steps, prompt flags and support levels stay in
    ///      the protocol, because a call's arguments are public (lens B5).
    function _contribution(address p, int256 delta, uint256 ts)
        internal pure returns (VWUEngine.SessionResult memory)
    {
        return VWUEngine.SessionResult({
            participant:       p,
            delta:             delta,
            session_timestamp: ts
        });
    }

    // There are no personal getters to test. They were removed by the lens B4
    // revision: the record is keyed by an address derived from the commitment,
    // nobody holds the key to it, and the functions returned an empty record to
    // every caller. A participant reads their own colours and points in the
    // application. What these tests check instead is what the engine publishes.

    function test_VWU_UnregisteredIsNotKnown() public {
        vm.prank(address(core));
        assertFalse(
            vwuEngine.isRegistered(participant),
            "An unregistered participant must not be known to the engine"
        );
    }

    function test_VWU_RegistrationIsCoordinatorOnly() public {
        vm.prank(participant);
        vm.expectRevert(VWUEngine.NotCoordinator.selector);
        vwuEngine.initializeParticipant(participant);
    }

    function test_VWU_BaseGrantedAtRegistration() public {
        vm.startPrank(address(core));
        vwuEngine.initializeParticipant(participant);
        assertTrue(
            vwuEngine.isRegistered(participant),
            "Registration must make the participant known to the engine"
        );
        vm.stopPrank();

        (uint256 solo, uint256 selfly, , , , ) = vwuEngine.getStatusDistribution();
        assertEq(selfly, 1, "Registration must place one star at the entry level");
        assertEq(
            solo,
            0,
            "SOLO stays empty while the base equals the SELFLY threshold"
        );
    }

    function test_VWU_UpdateRequiresRegistration() public {
        vm.prank(address(core));
        vm.expectRevert(
            abi.encodeWithSelector(VWUEngine.NotRegistered.selector, participant)
        );
        vwuEngine.updateVWU(_contribution(participant, 500, block.timestamp));
    }

    function test_VWU_OnlyCoordinator() public {
        vm.prank(address(core));
        vwuEngine.initializeParticipant(participant);

        vm.prank(participant); // not the coordinator
        vm.expectRevert(VWUEngine.NotCoordinator.selector);
        vwuEngine.updateVWU(_contribution(participant, 500, block.timestamp));
    }

    function test_VWU_NeverFallsBelowBase() public {
        vm.startPrank(address(core));
        vwuEngine.initializeParticipant(participant);
        // A contribution far below the floor. The rating already sits at the
        // base, so nothing can come off it and the applied delta is zero.
        int256 applied =
            vwuEngine.updateVWU(_contribution(participant, -100000, block.timestamp));
        vm.stopPrank();

        assertEq(applied, 0, "VWU must never fall below the non-burnable base");
    }

    function test_VWU_RationalFilterIsCounted() public {
        uint256 filter_before = vwuEngine.filterTotal();

        vm.startPrank(address(core));
        vwuEngine.initializeParticipant(participant);
        vwuEngine.updateVWU(_contribution(participant, -100000, block.timestamp));
        vm.stopPrank();

        assertEq(
            vwuEngine.filterTotal(),
            filter_before + 1,
            "A negative contribution is the rational filter and must be counted"
        );
    }

    function test_VWU_AbsenceDoesNotReduce() public {
        vm.startPrank(address(core));
        vwuEngine.initializeParticipant(participant);
        vwuEngine.updateVWU(_contribution(participant, 500, block.timestamp));

        vm.warp(block.timestamp + 200 days);

        int256 applied_after_absence =
            vwuEngine.updateVWU(_contribution(participant, 500, block.timestamp));
        vm.stopPrank();

        assertEq(
            applied_after_absence,
            500,
            "Absence must reduce neither the rating nor the next delta"
        );
    }

    // ─────────────────────────────────────────────────────────────
    // CORE CONTRACT TESTS
    // ─────────────────────────────────────────────────────────────

    function test_Core_RegisterParticipant() public {
        bytes memory zk_proof = hex""; // placeholder

        vm.prank(participant);
        core.register(IDENTITY_1, zk_proof);

        assertEq(core.getParticipantCount(), 1, "Registry should hold one participant");
    }

    function test_Core_RegistryIsAggregateOnly() public {
        bytes memory zk_proof = hex"";

        vm.prank(participant);
        core.register(IDENTITY_1, zk_proof);
        vm.prank(participant2);
        core.register(IDENTITY_2, zk_proof);

        // The contract reports how many are registered, never who.
        assertEq(core.getParticipantCount(), 2, "Registry should hold two participants");
    }

    function test_Core_RegisterGrantsBaseScore() public {
        bytes memory zk_proof = hex"";

        vm.prank(participant);
        core.register(IDENTITY_1, zk_proof);

        // Registration is one operation across two contracts: core calls the
        // engine, and the engine grants the base score. No getter returns that
        // score — the balance is read in the application — so what is checked
        // here is what the engine publishes: one star appears at the entry
        // level.
        (uint256 solo, uint256 selfly, , , , ) = vwuEngine.getStatusDistribution();
        assertEq(selfly, 1, "Registration must place one star at the entry level");
        assertEq(solo, 0, "SOLO stays empty while the base equals the SELFLY threshold");
    }

    function test_Core_DoubleRegisterFails() public {
        bytes memory zk_proof = hex"";

        vm.startPrank(participant);
        core.register(IDENTITY_1, zk_proof);

        vm.expectRevert("Already registered");
        core.register(IDENTITY_1, zk_proof);
        vm.stopPrank();
    }

    function test_Core_OpenSession() public {
        bytes32 dilemma_hash = keccak256("Should the community allocate budget to education or infrastructure?");

        // Opening a session is behind onlyCoordinator, and the coordinator is
        // the address passed to the constructor in setUp — not the deployer.
        vm.prank(coordinator);
        uint256 session_id = core.openSession(dilemma_hash, 3600);

        assertTrue(session_id > 0, "Session ID should be positive");
        assertTrue(core.isSessionActive(session_id), "Session should be active after opening");
    }

    function test_Core_SessionInactiveAfterTimeLock() public {
        bytes32 dilemma_hash = keccak256("Test dilemma");

        vm.prank(coordinator);
        uint256 session_id = core.openSession(dilemma_hash, 3600);

        // Warp past time lock
        vm.warp(block.timestamp + 3601);

        assertFalse(core.isSessionActive(session_id), "Session should be inactive after time lock");
    }

    /// @dev Helper: a Panorama of three rows over a roster of two participants.
    ///      The head of the Panorama — the roster — is not stored: it is these
    ///      three counts added together, and these three sums added together,
    ///      and finalizeSession refuses a result where that does not hold.
    function _panorama(uint256 session_id, uint256 base)
        internal pure returns (IBeTrueCore.SessionResult memory)
    {
        return IBeTrueCore.SessionResult({
            session_id:          session_id,
            count_option_a:      1,
            total_weight_a:      base,
            count_option_b:      1,
            total_weight_b:      base,
            count_silent:        0,
            total_weight_silent: 0,
            zk_proof_hash:       keccak256("valid_zk_proof"),
            verdict_option_a:    IBeTrueCore.Verdict.YELLOW,
            verdict_option_b:    IBeTrueCore.Verdict.GREEN
        });
    }

    /// @dev Helper: register two participants and open a session over them.
    function _sessionOverTwo() internal returns (uint256 session_id) {
        bytes memory zk_proof = hex"";

        vm.prank(participant);
        core.register(IDENTITY_1, zk_proof);
        vm.prank(participant2);
        core.register(IDENTITY_2, zk_proof);

        vm.prank(coordinator);
        session_id = core.openSession(keccak256("Test dilemma"), 3600);
    }

    function test_Core_VerdictIsUndeterminedBeforeFinalization() public {
        vm.prank(coordinator);
        uint256 session_id = core.openSession(keccak256("Test dilemma"), 3600);

        IBeTrueCore.Session memory s = core.getSession(session_id);
        assertEq(
            uint8(s.verdict_option_a),
            uint8(IBeTrueCore.Verdict.UNDETERMINED),
            "An unmeasured session must read as UNDETERMINED, never as RED or GREEN"
        );
        assertEq(
            uint8(s.verdict_option_b),
            uint8(IBeTrueCore.Verdict.UNDETERMINED),
            "An unmeasured session must read as UNDETERMINED, never as RED or GREEN"
        );
    }

    function test_Core_FinalizeSession() public {
        uint256 session_id = _sessionOverTwo();
        uint256 base = vwuEngine.VWU_BASE();

        // Warp past time lock
        vm.warp(block.timestamp + 3601);

        vm.prank(coordinator);
        core.finalizeSession(session_id, _panorama(session_id, base));

        IBeTrueCore.Session memory s = core.getSession(session_id);
        assertTrue(s.finalized, "Session should be finalized");
        assertEq(
            uint8(s.verdict_option_a),
            uint8(IBeTrueCore.Verdict.YELLOW),
            "Option A must carry its own verdict"
        );
        assertEq(
            uint8(s.verdict_option_b),
            uint8(IBeTrueCore.Verdict.GREEN),
            "Option B must carry its own verdict"
        );
        assertTrue(
            uint8(s.verdict_option_a) != uint8(s.verdict_option_b),
            "Each side carries its own colour, not one colour for the whole session"
        );
    }

    function test_Core_PanoramaRowsAccountForTheRoster() public {
        uint256 base = vwuEngine.VWU_BASE();
        IBeTrueCore.SessionResult memory result = _panorama(1, base);

        // Silence covers those who entered and chose neither option AND those
        // who did not take part at all, so the three rows account for the whole
        // roster — by people and by weight alike.
        assertEq(
            result.count_option_a + result.count_option_b + result.count_silent,
            2,
            "The three counts must add up to the roster"
        );
        assertEq(
            result.total_weight_a + result.total_weight_b + result.total_weight_silent,
            2 * base,
            "The three sums must add up to the weight of the roster"
        );
    }

    function test_Core_FinalizeBeforeTimeLockFails() public {
        uint256 session_id = _sessionOverTwo();
        uint256 base = vwuEngine.VWU_BASE();

        vm.prank(coordinator);
        vm.expectRevert("Time lock not reached");
        core.finalizeSession(session_id, _panorama(session_id, base));
    }

    function test_Core_RosterIsFixedWhenSessionOpens() public {
        bytes memory zk_proof = hex"";

        vm.prank(participant);
        core.register(IDENTITY_1, zk_proof);

        vm.prank(coordinator);
        uint256 session_id = core.openSession(keccak256("Test dilemma"), 3600);

        // A registration arriving while the session is open belongs to the
        // next session, not to this one.
        vm.prank(participant2);
        core.register(IDENTITY_2, zk_proof);

        IBeTrueCore.Session memory s = core.getSession(session_id);
        assertEq(s.roster_count, 1, "The roster is taken at open and does not move");
        assertEq(
            s.roster_weight,
            vwuEngine.VWU_BASE(),
            "The roster weight is taken at open and does not move"
        );
    }

    function test_Core_FinalizeRejectsRowsThatMissTheRoster() public {
        bytes memory zk_proof = hex"";

        vm.prank(participant);
        core.register(IDENTITY_1, zk_proof);

        vm.prank(coordinator);
        uint256 session_id = core.openSession(keccak256("Test dilemma"), 3600);
        vm.warp(block.timestamp + 3601);

        // One participant in the roster, but the rows account for none.
        IBeTrueCore.SessionResult memory result = IBeTrueCore.SessionResult({
            session_id:          session_id,
            count_option_a:      0,
            total_weight_a:      0,
            count_option_b:      0,
            total_weight_b:      0,
            count_silent:        0,
            total_weight_silent: 0,
            zk_proof_hash:       keccak256("proof"),
            verdict_option_a:    IBeTrueCore.Verdict.UNDETERMINED,
            verdict_option_b:    IBeTrueCore.Verdict.UNDETERMINED
        });

        vm.prank(coordinator);
        vm.expectRevert("Rows do not account for the roster");
        core.finalizeSession(session_id, result);
    }

    function test_Core_ParticipationMustCoverTheRoster() public {
        uint256 session_id = _sessionOverTwo();
        vm.warp(block.timestamp + 3601);

        uint256 base = vwuEngine.VWU_BASE();

        // One chose, one stayed silent. Both are in the roster, so both carry
        // weight in the rows.
        IBeTrueCore.SessionResult memory result = IBeTrueCore.SessionResult({
            session_id:          session_id,
            count_option_a:      1,
            total_weight_a:      base,
            count_option_b:      0,
            total_weight_b:      0,
            count_silent:        1,
            total_weight_silent: base,
            zk_proof_hash:       keccak256("proof"),
            verdict_option_a:    IBeTrueCore.Verdict.GREEN,
            verdict_option_b:    IBeTrueCore.Verdict.UNDETERMINED
        });

        vm.prank(coordinator);
        core.finalizeSession(session_id, result);

        // A list covering only the one who chose must be refused: the silent
        // participant is in the roster and gets a record like everyone else.
        bytes32[] memory one_commitment = new bytes32[](1);
        int256[]  memory one_delta      = new int256[](1);
        one_commitment[0] = IDENTITY_1;
        one_delta[0]      = 50;

        vm.prank(coordinator);
        vm.expectRevert("List does not cover the roster");
        core.applySessionParticipation(session_id, one_commitment, one_delta);

        // The full roster passes — the silent participant with a delta of
        // zero, because absence never reduces a rating.
        bytes32[] memory all_commitments = new bytes32[](2);
        int256[]  memory all_deltas      = new int256[](2);
        all_commitments[0] = IDENTITY_1;
        all_commitments[1] = IDENTITY_2;
        all_deltas[0]      = 50;
        all_deltas[1]      = 0;

        vm.prank(coordinator);
        core.applySessionParticipation(session_id, all_commitments, all_deltas);
    }

    // ─────────────────────────────────────────────────────────────
    // RECEIPT-FREENESS TESTS
    // ─────────────────────────────────────────────────────────────

    function test_NullifierPreventsDoubleVote() public {
        bytes32 dilemma_hash = keccak256("Test dilemma");

        vm.prank(coordinator);
        uint256 session_id = core.openSession(dilemma_hash, 3600);

        bytes32 nullifier      = keccak256("unique_nullifier_1");
        bytes memory enc_choice = hex"deadbeef";

        vm.startPrank(participant);
        core.submitChoice(session_id, enc_choice, nullifier);

        // Second submission with same nullifier should fail
        vm.expectRevert("Nullifier already used");
        core.submitChoice(session_id, enc_choice, nullifier);
        vm.stopPrank();
    }

    function test_DifferentNullifiersAllowed() public {
        // Distinct nullifiers are accepted because the contract cannot tell
        // whose they are. That is the property under test. It is not a choice
        // update: on this path a choice is never changed. One key yields one
        // nullifier for one session, the first call spends it, and a second
        // call carrying it is refused — see test_NullifierPreventsDoubleVote.
        // Changing a standing choice lives in Poll.publishMessage, not here.
        bytes32 dilemma_hash = keccak256("Test dilemma");

        vm.prank(coordinator);
        uint256 session_id = core.openSession(dilemma_hash, 3600);

        vm.startPrank(participant);
        core.submitChoice(session_id, hex"01", keccak256("nullifier_key_1"));
        core.submitChoice(session_id, hex"02", keccak256("nullifier_key_2"));
        core.submitChoice(session_id, hex"01", keccak256("nullifier_key_3"));
        vm.stopPrank();

        // Nothing above identifies a participant, so nothing above may be read
        // as one participant choosing three times. The test passes when no
        // call reverts.
    }
}
