// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title RegistrationFixtures
/// @notice Two real registration proofs, shared by every suite that registers
///         a participant.
/// @dev Why this file exists at all. Since 25 November 2026 register() in
///      src/BeTrueCoreCore.sol reads its proof argument, so a commitment can no
///      longer be invented: a test that registers has to present a commitment
///      that is the output of NINCommitment.circom together with the proof that
///      the prover knew its preimages. That is one commitment and eight field
///      elements per identity, needed in three suites — hence one file.
///
///      PROVENANCE, so that nobody takes these numbers for a hand-made
///      fixture. circom 2.2.3 compiled circuits/NINCommitment.circom by
///      circuits/COMPILE.md step 2b with --inspect and no warning; snarkjs
///      0.7.6 ran the Groth16 setup over the Hermez ptau of step 3 and
///      exported contracts/RegistrationVerifier.sol from the same zkey that
///      signed these two proofs. Each commitment was checked twice over: once
///      as the circuit's public signal, and once computed outside the circuit
///      by circomlibjs Poseidon. The two agreed to the digit, which is the
///      reason circomlib and circomlibjs are pinned together in package.json.
///
///      The witnesses behind them, kept here so the numbers can be rebuilt:
///        identity 1 — nin_preimage 123456789, salt 987654321, secret 555555555
///        identity 2 — nin_preimage 223456789, salt 887654321, secret 455555555
///      commitment = Poseidon(Poseidon(nin_preimage, salt), secret)
///
///      These values are not secret and not meaningful. They are test data, and
///      a real registration never lets any of the three leave the device.
///
///      THE ORDER INSIDE b IS NOT THE ORDER IN THE PROOF FILE, and this is the
///      one place where copying the numbers by eye goes wrong. snarkjs writes
///      the two coordinates of each G2 point one way in proof.json and the
///      other way in the calldata the Solidity verifier takes: b[0][0] here is
///      pi_b[0][1] there. The first attempt on 25 November 2026 took them
///      straight from proof.json — every proof verified off chain and every one
///      was refused on chain. These values come from
///      groth16.exportSolidityCallData, which does the swap itself. Take them
///      from there and from nowhere else.
///
///      A proof is bound to the verifying key it was made with. Regenerate the
///      key — another ceremony, any change to the circuit — and these numbers
///      stop verifying: regenerate the proofs with them, do not edit them.
///
///      One commitment is not derived from any address, then or now: an
///      identity anyone can recompute from an address is not a pseudonym.
abstract contract RegistrationFixtures {

    /// Commitment of witness 1 — the public signal of its proof.
    bytes32 internal constant IDENTITY_1 =
        bytes32(uint256(0x025b6bbdafdd80b7d225100dbc036510fa93ac4a2928918fbad2f9e3b53b456e));

    /// Commitment of witness 2.
    bytes32 internal constant IDENTITY_2 =
        bytes32(uint256(0x0bc65a477010456c56aa543cde5e23391dc10fa25c2cd0cc7b7512eded83180d));

    // ══════════════════════════════════════════════════════════════════════
    // Proof 1
    // ══════════════════════════════════════════════════════════════════════

    function _proof1A() internal pure returns (uint256[2] memory a) {
        a[0] = 0x2498d9dabc181311b2ac793a41a1384c6362dc13d8a3b2bb8fca58aa44e885be;
        a[1] = 0x13289623e1ab35b51140cbe2a057a4ecb1f17bb2e27d214a06aabf6ff39d343f;
    }

    function _proof1B() internal pure returns (uint256[2][2] memory b) {
        b[0][0] = 0x03d79253f4b4ace58509d26300951dac2fd2895cb10a67227f1895b2e508eaa9;
        b[0][1] = 0x0084d2c95e5f3ec8a1ed9ef64fef3b30e871625bef85abba4ffefd7ef20a21f5;
        b[1][0] = 0x112afc0416304bf959aef61faa5b0a9e40b354958c3ae2616d295df6938c2d7b;
        b[1][1] = 0x09bf3e27f3d2e537be5ab853a65be22501ecc94a2888f220a22361d24d43d1ea;
    }

    function _proof1C() internal pure returns (uint256[2] memory c) {
        c[0] = 0x078dc666bb36008e8469c1f3ac936c03748e56aeaea738d8c1b89dfd78328598;
        c[1] = 0x15756e6b3351556419e96a9ed13391d935e6a6d7b75523928781c6e3687418ce;
    }

    // ══════════════════════════════════════════════════════════════════════
    // Proof 2
    // ══════════════════════════════════════════════════════════════════════

    function _proof2A() internal pure returns (uint256[2] memory a) {
        a[0] = 0x09f563caf5a7343d2dcd914792e59f1364c70577cc602dd7ab2f507c445f5583;
        a[1] = 0x2df2437bc7b06b205b0e5cd2676cbc8f8f01c4a654c458fcaa2767f2dda38a29;
    }

    function _proof2B() internal pure returns (uint256[2][2] memory b) {
        b[0][0] = 0x24358df8ba57d850c904c9d36c69b804519bddfa8495b078a804c4265838f934;
        b[0][1] = 0x0f9e57f67e4b8652880fb9728f1bc0f8811485b3e282c7340070de9993b86e78;
        b[1][0] = 0x002cacf426e3af414f836e1eeb40b3d5bf5b3a4b94f7a42a32a118773e1a40ef;
        b[1][1] = 0x13315f1f780faab3bb837c3102b975fe2a014077699061ba989677bc2f41dab9;
    }

    function _proof2C() internal pure returns (uint256[2] memory c) {
        c[0] = 0x1c4d269587976540461c331fc69b69713cda56a2a1cb38ef103d0ae9434d1a9c;
        c[1] = 0x1b0a3cddb2bff127a1fcfe209c68153b8bb187bc779553c16529e8d2251c6ccf;
    }

    // ══════════════════════════════════════════════════════════════════════
    // What register() takes
    // ══════════════════════════════════════════════════════════════════════

    /// @dev The wire form of a proof: the three fixed-size arrays, encoded.
    ///      Exactly eight words, which is the length register() requires.
    function _encodeProof(
        uint256[2]    memory a,
        uint256[2][2] memory b,
        uint256[2]    memory c
    ) internal pure returns (bytes memory) {
        return abi.encode(a, b, c);
    }

    /// Proof for IDENTITY_1, ready to pass to register().
    function _registrationProof1() internal pure returns (bytes memory) {
        return _encodeProof(_proof1A(), _proof1B(), _proof1C());
    }

    /// Proof for IDENTITY_2, ready to pass to register().
    function _registrationProof2() internal pure returns (bytes memory) {
        return _encodeProof(_proof2A(), _proof2B(), _proof2C());
    }
}
