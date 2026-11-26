// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/IBeTrueCore.sol";
import "../src/BeTrueCoreCore.sol";
import "../src/EthicalMatrix.sol";
import "../src/HarmonyAgent.sol";
import "../src/VWUEngine.sol";
import "../contracts/RegistrationVerifier.sol";
import "./RegistrationFixtures.sol";

/// @title RegistrationProof
/// @notice The on-chain half of registration: register() in BeTrueCoreCore.sol
///         reads its proof argument, and what it will not accept is named here
///         one case at a time.
///
/// The sentence of the architecture this file holds to: an entry enters the
/// roster only when someone proved they knew the preimages of the commitment
/// being entered. Before 25 November 2026 the proof argument was accepted and
/// never read, and `register` was the widest of the three doors into the
/// roster listed in circuits/COMPILE.md.
///
/// WHAT IS NOT CLAIMED HERE, and the last two tests state it rather than leave
/// it to be assumed: the proof shows knowledge of three preimages, not that a
/// number was ever shown to the e-government gateway, and it binds nothing to
/// an address. One person who generates two secrets registers twice, and the
/// test named for that passes on purpose. Sybil-resistance at L0 therefore
/// remains an organisational guarantee — the client that checks the number at
/// the gateway, and whoever computes the tree root — and is to be named as
/// organisational wherever it is claimed.
///
/// The proofs come from RegistrationFixtures, which carries their provenance
/// and the ceremony behind their key: Phase 2 has one contributor, so this key
/// is for a test with no real community behind it.
contract RegistrationProofTest is Test, RegistrationFixtures {

    EthicalMatrix        internal matrix;
    HarmonyAgent         internal harmony;
    VWUEngine            internal engine;
    BeTrueCoreCore       internal core;
    RegistrationVerifier internal verifier;

    address internal deployer    = address(0x1);
    address internal coordinator = address(0x2);
    address internal anyone      = address(0xA11);
    address internal someoneElse = address(0xB22);

    function setUp() public {
        vm.startPrank(deployer);

        matrix   = new EthicalMatrix();
        engine   = new VWUEngine(coordinator);
        harmony  = new HarmonyAgent(address(matrix));
        verifier = new RegistrationVerifier();

        core = new BeTrueCoreCore(
            coordinator,
            address(matrix),
            address(harmony),
            address(engine),
            address(verifier)
        );

        matrix.setHarmonyAgent(address(harmony));
        engine.setCoordinator(address(core));

        vm.stopPrank();
    }

    // ══════════════════════════════════════════════════════════════════════
    // The generated verifier, on its own
    // ══════════════════════════════════════════════════════════════════════

    /// The verifier accepts the proof for the commitment it was made for.
    function test_the_verifier_accepts_the_proof_of_its_own_commitment() public view {
        uint256[1] memory signals = [uint256(IDENTITY_1)];
        assertTrue(verifier.verifyProof(_proof1A(), _proof1B(), _proof1C(), signals));
    }

    /// The same proof offered for another commitment proves nothing. Nothing
    /// inside the proof is touched here — only the statement.
    function test_the_verifier_refuses_the_same_proof_for_another_commitment() public view {
        uint256[1] memory signals = [uint256(IDENTITY_2)];
        assertFalse(verifier.verifyProof(_proof1A(), _proof1B(), _proof1C(), signals));
    }

    // ══════════════════════════════════════════════════════════════════════
    // Through register()
    // ══════════════════════════════════════════════════════════════════════

    /// A real proof registers, and the registry grows by one.
    function test_a_real_proof_registers() public {
        vm.prank(anyone);
        core.register(IDENTITY_1, _registrationProof1());

        assertEq(core.getParticipantCount(), 1, "the registry holds the entry");
    }

    /// One field element of the proof altered: the pairing no longer holds.
    function test_a_tampered_proof_is_refused() public {
        uint256[2] memory a = _proof1A();
        a[0] = a[0] + 1;

        vm.prank(anyone);
        vm.expectRevert("Invalid registration proof");
        core.register(IDENTITY_1, _encodeProof(a, _proof1B(), _proof1C()));
    }

    /// A proof that holds, presented for a commitment it does not prove. This
    /// is the sentence node У3 of the roadmap asks of this path: the proof is
    /// read against the argument of the call, not carried beside it.
    function test_a_proof_made_for_another_commitment_is_refused() public {
        vm.prank(anyone);
        vm.expectRevert("Invalid registration proof");
        core.register(IDENTITY_2, _registrationProof1());
    }

    /// The placeholder of the old path. Empty bytes were what every test and
    /// every caller used to pass, and the call succeeded. It cannot succeed
    /// again, and this test is here so that it cannot quietly start to.
    function test_an_empty_proof_is_refused() public {
        vm.prank(anyone);
        vm.expectRevert("Malformed registration proof");
        core.register(IDENTITY_1, "");
    }

    /// Eight words, no fewer and no more. A proof one byte short is refused
    /// with a word about its length rather than inside abi.decode.
    function test_a_proof_of_the_wrong_length_is_refused() public {
        bytes memory short_proof = new bytes(255);
        bytes memory long_proof  = new bytes(257);

        vm.startPrank(anyone);

        vm.expectRevert("Malformed registration proof");
        core.register(IDENTITY_1, short_proof);

        vm.expectRevert("Malformed registration proof");
        core.register(IDENTITY_1, long_proof);

        vm.stopPrank();
    }

    /// The order of the checks is itself the guarantee (lens B7). Whoever
    /// simulates this call locally to learn whether a commitment is already in
    /// the registry is answered by the proof, not by the registry: the reply is
    /// "Invalid registration proof" for an entry that exists, which is the same
    /// reply as for one that does not.
    function test_the_proof_is_checked_before_the_registry_is_read() public {
        vm.prank(anyone);
        core.register(IDENTITY_1, _registrationProof1());

        uint256[2] memory a = _proof1A();
        a[0] = a[0] + 1;

        // Registered, and still refused on the proof.
        vm.prank(someoneElse);
        vm.expectRevert("Invalid registration proof");
        core.register(IDENTITY_1, _encodeProof(a, _proof1B(), _proof1C()));

        // Not registered, refused the same way and with the same words.
        vm.prank(someoneElse);
        vm.expectRevert("Invalid registration proof");
        core.register(IDENTITY_2, _encodeProof(a, _proof1B(), _proof1C()));
    }

    /// A proof that holds, for a commitment already entered: refused on the
    /// registry, after the proof.
    function test_the_same_commitment_cannot_be_registered_twice() public {
        vm.startPrank(anyone);

        core.register(IDENTITY_1, _registrationProof1());

        vm.expectRevert("Already registered");
        core.register(IDENTITY_1, _registrationProof1());

        vm.stopPrank();
    }

    // ══════════════════════════════════════════════════════════════════════
    // What bounds entry, and what does not
    // ══════════════════════════════════════════════════════════════════════

    /// There is no ceiling on the roster, and that is a property of the
    /// architecture rather than an omission: by §6.4 of the preprint on
    /// communities without legal personality, neither an upper nor a lower
    /// limit on the size of a community is set, because a limit would turn
    /// size from a reading into a norm. What bounds this function is a gain
    /// and not a count, and the next two tests are that bound.

    /// What the bound is not. Two commitments, two proofs, one caller: both
    /// enter. The proof says its prover knew three preimages, and preimages are
    /// generated freely on the device — so this passes on purpose. It is §6.3
    /// of the preprint stated as a test: the protocol enforces one entry per
    /// registered secret, not one per citizen, and that a unit of participation
    /// is a person rests on the national identification number checked at the
    /// gateway, in the client. An organisational guarantee, to be named as one
    /// wherever Sybil-resistance is claimed for L0. What keeps the path from
    /// scaling is the rule by which weight arises, not a limit on entries: a
    /// hundred entries give a hundred beginners.
    function test_one_caller_with_two_proofs_enters_twice() public {
        vm.startPrank(anyone);
        core.register(IDENTITY_1, _registrationProof1());
        core.register(IDENTITY_2, _registrationProof2());
        vm.stopPrank();

        assertEq(core.getParticipantCount(), 2, "two entries, one caller, and nothing refused");
    }

    // ══════════════════════════════════════════════════════════════════════
    // Deployment
    // ══════════════════════════════════════════════════════════════════════

    /// The verifier is given once, at deployment, and there is no setter for
    /// it: a setter would be a role able to point registration at a verifier
    /// that accepts anything. A deployment that forgets it is refused outright
    /// instead of reverting later, inside every registration.
    function test_a_core_without_a_verifier_cannot_be_deployed() public {
        vm.expectRevert("Registration verifier required");
        new BeTrueCoreCore(
            coordinator,
            address(matrix),
            address(harmony),
            address(engine),
            address(0)
        );
    }
}
