// SPDX-License-Identifier: GPL-3.0
/*
    Copyright 2021 0KIMS association.

    This file is generated with [snarkJS](https://github.com/iden3/snarkjs).

    snarkJS is a free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    snarkJS is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
    or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public
    License for more details.

    You should have received a copy of the GNU General Public License
    along with snarkJS. If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity >=0.7.0 <0.9.0;


/// ─────────────────────────────────────────────────────────────────────────────
/// RENAMED BY HAND, AND THE RENAME IS THE ONLY EDIT.
///
/// snarkjs names every verifier it exports `Groth16Verifier`. This repository
/// now holds two of them: contracts/Verifier.sol for NINIdentityProof, the
/// voting circuit, and this one for NINCommitment, the registration circuit.
/// Two contracts under one name in one project collide, so this file's contract
/// is `RegistrationVerifier`. The already committed contracts/Verifier.sol
/// keeps the generated name — renaming it would invalidate nothing
/// cryptographically but would rewrite a file that is already tested and
/// referenced. Regenerating this file from the zkey reproduces the generated
/// name: rename it again, and change nothing else. Step 4b of
/// circuits/COMPILE.md says so beside the command.
///
/// WHAT THIS VERIFIER PROVES, exactly: that whoever made the proof knows a
/// nin_preimage, a registration_salt and an identity_secret whose Poseidon
/// chain equals the one public signal, the commitment. That is knowledge of
/// the preimages of a commitment. It is NOT a check that the number inside
/// was ever shown to the e-government gateway, and it binds nothing to an
/// address. Sybil-resistance at L0 therefore remains an organisational
/// guarantee and is to be named as organisational wherever it is claimed.
///
/// Public signal: one, the commitment. circom makes an output signal public
/// by definition of the language, and NINCommitment declares no public input,
/// so the list is exactly [identity_commitment] —
/// build/commitment/NINCommitment.sym, witness 1 = main.identity_commitment.
///
/// THE CEREMONY BEHIND THIS KEY. Phase 1 is the public Hermez ceremony,
/// powersOfTau28_hez_final_15.ptau, 37,831,832 bytes, blake2b-512
/// 982372c8…2969ae6e. Phase 2 has ONE contributor, who could forge a proof
/// for a commitment whose preimages nobody knows. Acceptable only while the
/// deployment is a test with no real community behind it; before the first
/// session with real participants, Phase 2 is run again in public with several
/// independent contributors and the deployed verifier is the one from that run.
/// ─────────────────────────────────────────────────────────────────────────────
contract RegistrationVerifier {
    // Scalar field size
    uint256 constant r    = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    // Base field size
    uint256 constant q   = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    // Verification Key data
    uint256 constant alphax  = 20491192805390485299153009773594534940189261866228447918068658471970481763042;
    uint256 constant alphay  = 9383485363053290200918347156157836566562967994039712273449902621266178545958;
    uint256 constant betax1  = 4252822878758300859123897981450591353533073413197771768651442665752259397132;
    uint256 constant betax2  = 6375614351688725206403948262868962793625744043794305715222011528459656738731;
    uint256 constant betay1  = 21847035105528745403288232691147584728191162732299865338377159692350059136679;
    uint256 constant betay2  = 10505242626370262277552901082094356697409835680220590971873171140371331206856;
    uint256 constant gammax1 = 11559732032986387107991004021392285783925812861821192530917403151452391805634;
    uint256 constant gammax2 = 10857046999023057135944570762232829481370756359578518086990519993285655852781;
    uint256 constant gammay1 = 4082367875863433681332203403145435568316851327593401208105741076214120093531;
    uint256 constant gammay2 = 8495653923123431417604973247489272438418190587263600148770280649306958101930;
    uint256 constant deltax1 = 6172191550542800850242932633909909877732150382679574355621171245282556099765;
    uint256 constant deltax2 = 21075425492911694264211576895196892198876996424131618254339008352194943242733;
    uint256 constant deltay1 = 5764625424477486327956598959594901726605985661525300090909066837810473975429;
    uint256 constant deltay2 = 17135007405796598480675006817982032853395912046893822622666916390210999996610;

    
    uint256 constant IC0x = 723726189596903049625574171163217314981108382562159874159397875770814806041;
    uint256 constant IC0y = 11044370136877379958158711948849610597859774695033219360914491591230773048008;
    
    uint256 constant IC1x = 2718277356253344123392688588855545071777873193346169168528685817810409901215;
    uint256 constant IC1y = 6673128679663987582841814799917667890699033060089070971401663326983301680312;
    
 
    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[1] calldata _pubSignals) public view returns (bool) {
        assembly {
            function checkField(v) {
                if iszero(lt(v, r)) {
                    mstore(0, 0)
                    return(0, 0x20)
                }
            }
            
            // G1 function to multiply a G1 value(x,y) to value in an address
            function g1_mulAccC(pR, x, y, s) {
                let success
                let mIn := mload(0x40)
                mstore(mIn, x)
                mstore(add(mIn, 32), y)
                mstore(add(mIn, 64), s)

                success := staticcall(sub(gas(), 2000), 7, mIn, 96, mIn, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }

                mstore(add(mIn, 64), mload(pR))
                mstore(add(mIn, 96), mload(add(pR, 32)))

                success := staticcall(sub(gas(), 2000), 6, mIn, 128, pR, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }
            }

            function checkPairing(pA, pB, pC, pubSignals, pMem) -> isOk {
                let _pPairing := add(pMem, pPairing)
                let _pVk := add(pMem, pVk)

                mstore(_pVk, IC0x)
                mstore(add(_pVk, 32), IC0y)

                // Compute the linear combination vk_x
                
                g1_mulAccC(_pVk, IC1x, IC1y, calldataload(add(pubSignals, 0)))
                

                // -A
                mstore(_pPairing, calldataload(pA))
                mstore(add(_pPairing, 32), mod(sub(q, calldataload(add(pA, 32))), q))

                // B
                mstore(add(_pPairing, 64), calldataload(pB))
                mstore(add(_pPairing, 96), calldataload(add(pB, 32)))
                mstore(add(_pPairing, 128), calldataload(add(pB, 64)))
                mstore(add(_pPairing, 160), calldataload(add(pB, 96)))

                // alpha1
                mstore(add(_pPairing, 192), alphax)
                mstore(add(_pPairing, 224), alphay)

                // beta2
                mstore(add(_pPairing, 256), betax1)
                mstore(add(_pPairing, 288), betax2)
                mstore(add(_pPairing, 320), betay1)
                mstore(add(_pPairing, 352), betay2)

                // vk_x
                mstore(add(_pPairing, 384), mload(add(pMem, pVk)))
                mstore(add(_pPairing, 416), mload(add(pMem, add(pVk, 32))))


                // gamma2
                mstore(add(_pPairing, 448), gammax1)
                mstore(add(_pPairing, 480), gammax2)
                mstore(add(_pPairing, 512), gammay1)
                mstore(add(_pPairing, 544), gammay2)

                // C
                mstore(add(_pPairing, 576), calldataload(pC))
                mstore(add(_pPairing, 608), calldataload(add(pC, 32)))

                // delta2
                mstore(add(_pPairing, 640), deltax1)
                mstore(add(_pPairing, 672), deltax2)
                mstore(add(_pPairing, 704), deltay1)
                mstore(add(_pPairing, 736), deltay2)


                let success := staticcall(sub(gas(), 2000), 8, _pPairing, 768, _pPairing, 0x20)

                isOk := and(success, mload(_pPairing))
            }

            let pMem := mload(0x40)
            mstore(0x40, add(pMem, pLastMem))

            // Validate that all evaluations ∈ F
            
            checkField(calldataload(add(_pubSignals, 0)))
            

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
             return(0, 0x20)
         }
     }
 }
