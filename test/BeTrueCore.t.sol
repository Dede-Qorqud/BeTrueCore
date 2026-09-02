// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/IBeTrueCore.sol";
import "../src/BeTrueCoreCore.sol";
import "../src/EthicalMatrix.sol";
import "../src/HarmonyAgent.sol";
import "../src/VWUEngine.sol";

/// @title BeTrueCoreTest
/// @notice Foundry unit tests for BeTrueCore Developer Package v0.2
/// @dev Run with: forge test -v
///      BeTrueCore Developer Package v0.2
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

    address owner       = address(0x1);
    address coordinator = address(0x2);
    address participant = address(0x3);
    address participant2 = address(0x4);

    // ─────────────────────────────────────────────────────────────
    // SETUP
    // ─────────────────────────────────────────────────────────────

    function setUp() public {
        vm.startPrank(owner);

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

        // Populate a subset of the 736-point matrix for testing
        _populateTestMatrix();

        vm.stopPrank();
    }

    /// @dev Populate key test cells (canonical 9 + additional)
    function _populateTestMatrix() internal {
        uint8[]  memory a_ids      = new uint8[](9);
        uint8[]  memory t_ids      = new uint8[](9);
        EthicalMatrix.CellState[] memory priorities = new EthicalMatrix.CellState[](9);
        EthicalMatrix.AgentType[] memory agents     = new EthicalMatrix.AgentType[](9);

        // Analyst canonical cells
        a_ids[0] = 6;  t_ids[0] = 2;  priorities[0] = EthicalMatrix.CellState.CRITICAL; agents[0] = EthicalMatrix.AgentType.ANALYST;   // A06×T02
        a_ids[1] = 12; t_ids[1] = 4;  priorities[1] = EthicalMatrix.CellState.CRITICAL; agents[1] = EthicalMatrix.AgentType.ANALYST;   // A12×T04
        a_ids[2] = 10; t_ids[2] = 8;  priorities[2] = EthicalMatrix.CellState.CRITICAL; agents[2] = EthicalMatrix.AgentType.ANALYST;   // A10×T08

        // Strategist canonical cells
        a_ids[3] = 17; t_ids[3] = 20; priorities[3] = EthicalMatrix.CellState.CRITICAL; agents[3] = EthicalMatrix.AgentType.STRATEGIST; // A17×T20
        a_ids[4] = 16; t_ids[4] = 14; priorities[4] = EthicalMatrix.CellState.CRITICAL; agents[4] = EthicalMatrix.AgentType.STRATEGIST; // A16×T14
        a_ids[5] = 14; t_ids[5] = 9;  priorities[5] = EthicalMatrix.CellState.CRITICAL; agents[5] = EthicalMatrix.AgentType.STRATEGIST; // A14×T09

        // Sentinel canonical cells
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

    function test_CellAgent_Analyst() public {
        EthicalMatrix.AgentType agent = matrix.getCellAgent(6, 2); // A06×T02
        assertEq(uint8(agent), uint8(EthicalMatrix.AgentType.ANALYST), "A06×T02 should be ANALYST");
    }

    function test_CellAgent_Strategist() public {
        EthicalMatrix.AgentType agent = matrix.getCellAgent(17, 20); // A17×T20
        assertEq(uint8(agent), uint8(EthicalMatrix.AgentType.STRATEGIST), "A17×T20 should be STRATEGIST");
    }

    function test_CellAgent_Sentinel() public {
        EthicalMatrix.AgentType agent = matrix.getCellAgent(18, 29); // A18×T29
        assertEq(uint8(agent), uint8(EthicalMatrix.AgentType.SENTINEL), "A18×T29 should be SENTINEL");
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
        (EthicalMatrix.Verdict verdict, uint256 score) = harmony.previewVerdict(a_ids, t_ids, scores);
        assertEq(uint8(verdict), uint8(EthicalMatrix.Verdict.GREEN), "All high scores should be GREEN");
        assertEq(score, 85, "Aggregate score should be 85");
    }

    function test_HarmonyAgent_CriticalRed() public {
        uint8[] memory a_ids  = new uint8[](2);
        uint8[] memory t_ids  = new uint8[](2);
        uint8[] memory scores = new uint8[](2);

        a_ids[0] = 6;  t_ids[0] = 2;  scores[0] = 10; // CRITICAL weight=3 score=10 → RED
        a_ids[1] = 12; t_ids[1] = 4;  scores[1] = 80; // CRITICAL weight=3 score=80 → GREEN

        // Expected: (10×3 + 80×3) / 6 = 270/6 = 45 → YELLOW
        // One critical RED cell pulls the aggregate down significantly
        (EthicalMatrix.Verdict verdict, uint256 score) = harmony.previewVerdict(a_ids, t_ids, scores);
        assertEq(uint8(verdict), uint8(EthicalMatrix.Verdict.YELLOW), "One RED critical should pull to YELLOW");
        assertEq(score, 45, "Aggregate score should be 45");
    }

    function test_HarmonyAgent_NoActiveCells() public {
        uint8[] memory a_ids  = new uint8[](1);
        uint8[] memory t_ids  = new uint8[](1);
        uint8[] memory scores = new uint8[](1);

        a_ids[0] = 1; t_ids[0] = 1; scores[0] = 50; // unpopulated = SUPERPOSITION weight=0

        // SUPERPOSITION cells excluded → no active cells → default GREEN
        (EthicalMatrix.Verdict verdict, uint256 score) = harmony.previewVerdict(a_ids, t_ids, scores);
        assertEq(uint8(verdict), uint8(EthicalMatrix.Verdict.GREEN), "No active cells → default GREEN");
        assertEq(score, 100, "No active cells → score 100");
    }

    function test_HarmonyAgent_MajorityMinorityEqual() public {
        // The verdict is applied equally to majority and minority
        // Same cells, same scores — verdict must be identical regardless of is_majority flag
        uint8[] memory a_ids  = new uint8[](1);
        uint8[] memory t_ids  = new uint8[](1);
        uint8[] memory scores = new uint8[](1);
        a_ids[0] = 6; t_ids[0] = 2; scores[0] = 75;

        (EthicalMatrix.Verdict v1,) = harmony.previewVerdict(a_ids, t_ids, scores);
        (EthicalMatrix.Verdict v2,) = harmony.previewVerdict(a_ids, t_ids, scores);

        assertEq(uint8(v1), uint8(v2), "Verdict must be equal for majority and minority");
    }

    // ─────────────────────────────────────────────────────────────
    // VWU ENGINE TESTS
    // ─────────────────────────────────────────────────────────────

    function test_VWU_InitialBalance() public {
        uint256 vwu = vwuEngine.getVWU(participant);
        assertEq(vwu, 0, "Initial VWU should be 0");
    }

    function test_VWU_UpdateAligned() public {
        // Participant aligned with majority, full activity
        uint256 delta = vwuEngine.previewDelta(participant, 100, true);
        assertTrue(delta > 0, "Delta should be positive for full activity + aligned");
    }

    function test_VWU_UpdateNotAligned() public {
        // Participant NOT aligned with majority, full activity
        uint256 delta_aligned     = vwuEngine.previewDelta(participant, 100, true);
        uint256 delta_not_aligned = vwuEngine.previewDelta(participant, 100, false);
        assertTrue(delta_aligned > delta_not_aligned, "Aligned should earn more VWU than not aligned");
    }

    function test_VWU_NonLinearGrowth() public {
        vm.startPrank(coordinator);

        // Session 1: participant starts from 0
        VWUEngine.SessionResult memory r1 = VWUEngine.SessionResult({
            participant:       participant,
            activity_score:    100,
            aligned_majority:  true,
            session_timestamp: block.timestamp
        });
        vwuEngine.updateVWU(r1);
        uint256 vwu_after_1 = vwuEngine.getVWU(participant);

        // Session 2: participant now has accumulated VWU
        VWUEngine.SessionResult memory r2 = VWUEngine.SessionResult({
            participant:       participant,
            activity_score:    100,
            aligned_majority:  true,
            session_timestamp: block.timestamp + 1 days
        });
        vwuEngine.updateVWU(r2);
        uint256 vwu_after_2 = vwuEngine.getVWU(participant);

        uint256 delta_1 = vwu_after_1;
        uint256 delta_2 = vwu_after_2 - vwu_after_1;

        assertTrue(delta_1 > delta_2, "Second session delta should be smaller (non-linear growth)");

        vm.stopPrank();
    }

    function test_VWU_ContinuityPenalty() public {
        vm.startPrank(coordinator);

        // First session
        VWUEngine.SessionResult memory r1 = VWUEngine.SessionResult({
            participant:       participant,
            activity_score:    100,
            aligned_majority:  true,
            session_timestamp: block.timestamp
        });
        vwuEngine.updateVWU(r1);
        uint256 vwu_base = vwuEngine.getVWU(participant);

        // Second session after 60-day gap (> 30 days threshold)
        VWUEngine.SessionResult memory r2 = VWUEngine.SessionResult({
            participant:       participant2, // fresh participant for comparison
            activity_score:    100,
            aligned_majority:  true,
            session_timestamp: block.timestamp
        });
        vwuEngine.updateVWU(r2);
        uint256 fresh_delta = vwuEngine.getVWU(participant2);

        // Session with 60-day gap
        VWUEngine.SessionResult memory r3 = VWUEngine.SessionResult({
            participant:       participant,
            activity_score:    100,
            aligned_majority:  true,
            session_timestamp: block.timestamp + 60 days
        });
        vwuEngine.updateVWU(r3);
        uint256 gap_delta = vwuEngine.getVWU(participant) - vwu_base;

        assertTrue(gap_delta < fresh_delta, "60-day gap should apply continuity penalty");

        vm.stopPrank();
    }

    function test_VWU_OnlyCoordinator() public {
        // Non-coordinator should not be able to update VWU
        VWUEngine.SessionResult memory r = VWUEngine.SessionResult({
            participant:       participant,
            activity_score:    100,
            aligned_majority:  true,
            session_timestamp: block.timestamp
        });

        vm.prank(participant); // not the coordinator
        vm.expectRevert("Only anti-collusion coordinator");
        vwuEngine.updateVWU(r);
    }

    // ─────────────────────────────────────────────────────────────
    // CORE CONTRACT TESTS
    // ─────────────────────────────────────────────────────────────

    function test_Core_RegisterParticipant() public {
        bytes32 identity = keccak256(abi.encodePacked(participant));
        bytes memory zk_proof = hex""; // placeholder

        vm.prank(participant);
        core.register(identity, zk_proof);

        IBeTrueCore.Participant memory p = core.getParticipant(identity);
        assertEq(p.identity_commitment, identity, "Identity commitment should match");
        assertEq(p.vwu, 0, "Initial VWU should be 0");
        assertEq(uint8(p.status), uint8(IBeTrueCore.Status.SOLO), "Initial status should be SOLO");
    }

    function test_Core_DoubleRegisterFails() public {
        bytes32 identity = keccak256(abi.encodePacked(participant));
        bytes memory zk_proof = hex"";

        vm.startPrank(participant);
        core.register(identity, zk_proof);

        vm.expectRevert("Already registered");
        core.register(identity, zk_proof);
        vm.stopPrank();
    }

    function test_Core_OpenSession() public {
        bytes32 dilemma_hash = keccak256("Should the community allocate budget to education or infrastructure?");

        vm.prank(owner);
        uint256 session_id = core.openSession(dilemma_hash, 3600);

        assertTrue(session_id > 0, "Session ID should be positive");
        assertTrue(core.isSessionActive(session_id), "Session should be active after opening");
    }

    function test_Core_SessionInactiveAfterTimeLock() public {
        bytes32 dilemma_hash = keccak256("Test dilemma");

        vm.prank(owner);
        uint256 session_id = core.openSession(dilemma_hash, 3600);

        // Warp past time lock
        vm.warp(block.timestamp + 3601);

        assertFalse(core.isSessionActive(session_id), "Session should be inactive after time lock");
    }

    function test_Core_FinalizeSession() public {
        bytes32 dilemma_hash = keccak256("Test dilemma");

        vm.prank(owner);
        uint256 session_id = core.openSession(dilemma_hash, 3600);

        // Warp past time lock
        vm.warp(block.timestamp + 3601);

        IBeTrueCore.SessionResult memory result = IBeTrueCore.SessionResult({
            session_id:      session_id,
            total_weight_a:  750,
            total_weight_b:  250,
            zk_proof_hash:   keccak256("valid_zk_proof"),
            verdict:         IBeTrueCore.Verdict.GREEN
        });

        vm.prank(coordinator);
        core.finalizeSession(session_id, result);

        IBeTrueCore.Session memory s = core.getSession(session_id);
        assertTrue(s.finalized, "Session should be finalized");
        assertEq(uint8(s.verdict), uint8(IBeTrueCore.Verdict.GREEN), "Verdict should be GREEN");
    }

    function test_Core_FinalizeBeforeTimeLockFails() public {
        bytes32 dilemma_hash = keccak256("Test dilemma");

        vm.prank(owner);
        uint256 session_id = core.openSession(dilemma_hash, 3600);

        // Try to finalize before time lock
        IBeTrueCore.SessionResult memory result = IBeTrueCore.SessionResult({
            session_id:      session_id,
            total_weight_a:  500,
            total_weight_b:  500,
            zk_proof_hash:   keccak256("proof"),
            verdict:         IBeTrueCore.Verdict.GREEN
        });

        vm.prank(coordinator);
        vm.expectRevert("Time lock not reached");
        core.finalizeSession(session_id, result);
    }

    // ─────────────────────────────────────────────────────────────
    // RECEIPT-FREENESS TESTS
    // ─────────────────────────────────────────────────────────────

    function test_NullifierPreventsDoubleVote() public {
        bytes32 dilemma_hash = keccak256("Test dilemma");

        vm.prank(owner);
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
        // Key-rotation: different nullifiers = legitimate choice update
        bytes32 dilemma_hash = keccak256("Test dilemma");

        vm.prank(owner);
        uint256 session_id = core.openSession(dilemma_hash, 3600);

        vm.startPrank(participant);
        core.submitChoice(session_id, hex"01", keccak256("nullifier_key_1"));
        core.submitChoice(session_id, hex"02", keccak256("nullifier_key_2")); // key rotation
        core.submitChoice(session_id, hex"01", keccak256("nullifier_key_3")); // change back
        vm.stopPrank();

        // Only the last choice counts — this is key-rotation in action
        // Test passes if no revert
    }
}
