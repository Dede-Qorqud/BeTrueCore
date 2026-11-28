// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/Verifier.sol";
import "../contracts/NINNullifierRegistry.sol";

/// @title VerifierRegistry
/// @notice The on-chain half of the first identity proof: a real Groth16 proof
///         for NINIdentityProof(20) is checked by the generated verifier through
///         NINNullifierRegistry, and a proof that does not hold is refused.
///
/// What this test states as a sentence of the architecture: the registry admits
/// an entry only when the circuit's statement is proved on chain, and an entry
/// under a nullifier already spent in that session is refused.
///
/// The proof below is not a fixture invented by hand. It was produced by
/// circuits/COMPILE.md steps 2-4: circom 2.2.3 compiled
/// circuits/NINIdentityProof.circom at LEVELS = 20, snarkjs 0.7.6 ran the
/// Groth16 setup and exported contracts/Verifier.sol from the same zkey that
/// signed this proof. The witness came from the test data of COMPILE.md step 5
/// — the leaf at the far left of the tree, every sibling zero — so the public
/// signals are:
///
///   [0] nullifier          = Poseidon(identity_secret, session_id)
///   [1] merkle_root        = the leaf hashed upward 20 times
///   [2] external_nullifier = session_id = 1
///
/// The order is the circuit's, not a choice made here: circom places outputs
/// before public inputs, and build20/NINIdentityProof.sym confirms it —
/// witness 1 = nullifier, 2 = merkle_root, 3 = external_nullifier.
///
/// A proof is bound to the verifying key it was made with. Regenerate the key
/// (another ceremony, another depth, any change to the circuit) and these
/// numbers stop verifying: regenerate the proof with them, do not edit them.
///
/// THE CEREMONY BEHIND THIS KEY, so that nobody reads more into it than it
/// says. Phase 1 is the public Hermez ceremony: powersOfTau28_hez_final_15.ptau,
/// 37,831,832 bytes, blake2b-512 982372c8…2969ae6e, checked against the value
/// snarkjs publishes for that file. Both of Hermez's own buckets answer 403
/// since September 2026, so the bytes came from a mirror and the hash is what
/// makes the mirror not worth trusting either way. Phase 2 has ONE contributor,
/// and that contributor could forge a membership proof for a leaf that is not
/// in the tree. The note in circuits/COMPILE.md step 3 allows this only while
/// the deployment is a test with no real community behind it — which is what
/// this file is. Before the first session with real participants, Phase 2 is
/// run again in public with several independent contributors, and the deployed
/// verifier is the one built from that run, not this one.
/// @notice Stands in for BeTrueCoreCore, under the one call the registry makes
/// @dev The registry asks a session for the root it opened with. Here the
///      answer is the root the real proof below was built against, which is
///      all this suite needs from a core. How a real core arrives at that
///      value — the queue, the tree, the snapshot taken at openSession — is
///      asserted in test/Assertions.t.sol and test/CompositionTree.t.sol. A
///      promise checked against a stand-in is checked against nothing.
contract SessionRootsStub {
    mapping(uint256 => uint256) private roots;

    function setRoot(uint256 session_id, uint256 root) external {
        roots[session_id] = root;
    }

    function sessionRoot(uint256 session_id) external view returns (uint256) {
        return roots[session_id];
    }
}

contract VerifierRegistryTest is Test {

    Groth16Verifier        internal verifier;
    NINNullifierRegistry   internal registry;
    SessionRootsStub       internal core;

    /// Stands in for Poll.sol, which is the only permitted caller.
    address internal constant POLL = address(0xB011);

    uint256 internal constant SESSION_ID = 1;

    bytes32 internal constant MERKLE_ROOT =
        bytes32(uint256(0x22ccf38d06c626ed1d1019a8fce9a65ff4238e93f9bd3b52dd34417faa41fc1a));

    bytes32 internal constant NULLIFIER =
        bytes32(uint256(0x1ce437246fd9d28f3d6cd63056c97572ef73fce1a2455a0760b813f19d1a130c));

    function _proofA() internal pure returns (uint256[2] memory a) {
        a[0] = 0x299fb64ffd3a67355baeaef01c28ee71cde19d25b9e5f8fa2f5f88d296b409d1;
        a[1] = 0x0ef8311ebfe73c7e6850098d5871dc2a619cd0cbf0f817c6c431f8545c90744e;
    }

    function _proofB() internal pure returns (uint256[2][2] memory b) {
        b[0][0] = 0x2752ba927c0870c3e198a24858ad9fa21634942d4908736e189ad57b1e0fa70b;
        b[0][1] = 0x180bdae0c11f3c31332d48ee2ff63e268edbd113b80c8fd2b31e104dee620366;
        b[1][0] = 0x1e045bdab50066238c1193ed2b1045e117d95a922ff9ffd3e0755e2d9e6a2893;
        b[1][1] = 0x13ab2584baf5492179ef79c5cb7e9ed47211d4116211b93041c0c9390d27fe1a;
    }

    function _proofC() internal pure returns (uint256[2] memory c) {
        c[0] = 0x1fefc2db7a1638d677638ecf32fcde3686ab8701f696fd0fcff4d29a554f2e31;
        c[1] = 0x2f53a032d1b47d57ae898319adf529b26656b5ae211f721a5618e051a2e97d5a;
    }

    function setUp() public {
        verifier = new Groth16Verifier();

        // The registry holds no root of its own any more. It asks the session
        // which root that session opened with, so the suite puts the root the
        // proof was built against where the session would have it.
        core = new SessionRootsStub();
        core.setRoot(SESSION_ID, uint256(MERKLE_ROOT));

        registry = new NINNullifierRegistry(address(verifier), address(core));
        registry.setPoll(POLL);

    // ══════════════════════════════════════════════════════════════════════
    // The generated verifier, on its own
    // ══════════════════════════════════════════════════════════════════════

    /// The verifier accepts the proof for the statement it was made for.
    function test_Verifier_AcceptsValidProof() public view {
        uint256[3] memory input = [
            uint256(NULLIFIER),
            uint256(MERKLE_ROOT),
            SESSION_ID
        ];
        assertTrue(verifier.verifyProof(_proofA(), _proofB(), _proofC(), input));
    }

    /// The same proof presented for another nullifier proves nothing.
    /// Nothing is tampered inside the proof here: only the statement is.
    function test_Verifier_RejectsOtherStatement() public view {
        uint256[3] memory input = [
            uint256(NULLIFIER) + 1,
            uint256(MERKLE_ROOT),
            SESSION_ID
        ];
        assertFalse(verifier.verifyProof(_proofA(), _proofB(), _proofC(), input));
    }

    // ══════════════════════════════════════════════════════════════════════
    // Through the registry
    // ══════════════════════════════════════════════════════════════════════

    /// A valid proof is verified on chain and the nullifier is spent.
    function test_Registry_ValidProofRegisters() public {
        assertFalse(registry.isNullifierUsed(SESSION_ID, NULLIFIER));

        vm.prank(POLL);
        bool ok = registry.verifyAndRegister(
            SESSION_ID, NULLIFIER, _proofA(), _proofB(), _proofC()
        );

        assertTrue(ok);
        assertTrue(registry.isNullifierUsed(SESSION_ID, NULLIFIER));
    }

    /// A nullifier the proof does not prove is refused. This is the sentence
    /// the node У3 of the roadmap asks of the registration path: the proof
    /// argument is read, not carried.
    function test_Registry_RejectsProofForAnotherNullifier() public {
        bytes32 wrong = bytes32(uint256(NULLIFIER) + 1);

        vm.prank(POLL);
        vm.expectRevert(NINNullifierRegistry.InvalidZKProof.selector);
        registry.verifyAndRegister(
            SESSION_ID, wrong, _proofA(), _proofB(), _proofC()
        );
    }

    /// One field element of the proof altered: the pairing no longer holds.
    function test_Registry_RejectsTamperedProof() public {
        uint256[2] memory a = _proofA();
        a[0] = a[0] + 1;

        vm.prank(POLL);
        vm.expectRevert(NINNullifierRegistry.InvalidZKProof.selector);
        registry.verifyAndRegister(
            SESSION_ID, NULLIFIER, a, _proofB(), _proofC()
        );
    }

    /// The same proof twice in one session: the second entry is refused on the
    /// nullifier, before the pairing is even reached.
    function test_Registry_SecondEntryUnderSameNullifierRefused() public {
        vm.prank(POLL);
        registry.verifyAndRegister(
            SESSION_ID, NULLIFIER, _proofA(), _proofB(), _proofC()
        );

        vm.prank(POLL);
        vm.expectRevert(
            abi.encodeWithSelector(
                NINNullifierRegistry.NullifierAlreadyUsed.selector,
                SESSION_ID,
                NULLIFIER
            )
        );
        registry.verifyAndRegister(
            SESSION_ID, NULLIFIER, _proofA(), _proofB(), _proofC()
        );
    }

    /// Anyone but Poll.sol is refused before the proof is read at all.
    function test_Registry_OnlyPollMaySubmit() public {
        vm.expectRevert(NINNullifierRegistry.OnlyPoll.selector);
        registry.verifyAndRegister(
            SESSION_ID, NULLIFIER, _proofA(), _proofB(), _proofC()
        );
    }

    /// A session that never opened has no root, and the registry says which
    /// session rather than verifying against zero — which no honest proof
    /// satisfies and which would fail with nothing naming the cause.
    function test_Registry_RefusesASessionThatNeverOpened() public {
        vm.prank(POLL);
        vm.expectRevert(
            abi.encodeWithSelector(
                NINNullifierRegistry.SessionHasNoRoot.selector, uint256(99)
            )
        );
        registry.verifyAndRegister(
            99, NULLIFIER, _proofA(), _proofB(), _proofC()
        );
    }

    /// The root is the session's, not the registry's: the registry reads it
    /// through and holds nothing of its own to go stale.
    function test_Registry_ReadsTheRootThroughFromTheSession() public {
        assertEq(
            registry.sessionMerkleRoot(SESSION_ID),
            uint256(MERKLE_ROOT),
            "the root in force for this session"
        );

        core.setRoot(SESSION_ID, uint256(MERKLE_ROOT) + 1);

        assertEq(
            registry.sessionMerkleRoot(SESSION_ID),
            uint256(MERKLE_ROOT) + 1,
            "and it follows the session, because the registry keeps no copy"
        );
    }
}
