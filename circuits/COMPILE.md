# BeTrueCore — ZK Identity: Compile & Deploy Guide

**Circuit version:** 0.1 — MVP  
**Author:** Farman Guliyev (Safarnur) · github.com/Dede-Qorqud/BeTrueCore

---

## File Structure

```
BeTrueCore/
├── circuits/
│   ├── NINCommitment.circom        — Registration: NIN → commitment
│   ├── NINIdentityProof.circom     — Voting: Merkle membership + nullifier
│   └── lib/
│       └── BinaryMerkleTree.circom — Poseidon Merkle tree (helper library)
└── contracts/
    └── NINNullifierRegistry.sol    — On-chain ZK proof registry + verifier interface
```

---

## Step 1 — Install Dependencies

```bash
# Node.js 20 LTS required
npm init -y
npm install circomlib snarkjs
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox
```

---

## Step 2 — Compile NINIdentityProof Circuit

```bash
# Compile circuit → R1CS + WASM + SYM
# -l node_modules: path to circomlib
circom circuits/NINIdentityProof.circom \
  --r1cs \
  --wasm \
  --sym \
  -l node_modules \
  -o build/

# Check constraint count (expected: ~5,000–8,000 for LEVELS=20)
snarkjs r1cs info build/NINIdentityProof.r1cs
```

**For pilot (50–100 participants)** — change the last line of `NINIdentityProof.circom`:
```circom
// Change LEVELS from 20 to 7:
component main {public [merkle_root, external_nullifier]} = NINIdentityProof(7);
// LEVELS=7 supports up to 128 participants, faster proof generation
```

---

## Step 3 — Trusted Setup (Powers of Tau)

Groth16 requires a trusted setup. For testnet/pilot we use
the Hermez public ceremony (BN254 curve, ~100M participants).

```bash
# Download ptau file from Hermez public ceremony (~200MB)
curl -L https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_15.ptau \
     -o pot15_final.ptau

# Phase 2 setup — circuit-specific
snarkjs groth16 setup \
  build/NINIdentityProof.r1cs \
  pot15_final.ptau \
  keys/NINIdentityProof_0000.zkey

# Add your contribution (required — without this the setup is cryptographically unsafe)
snarkjs zkey contribute \
  keys/NINIdentityProof_0000.zkey \
  keys/NINIdentityProof_0001.zkey \
  --name="BeTrueCore MVP contribution" \
  -v

# Export verification key
snarkjs zkey export verificationkey \
  keys/NINIdentityProof_0001.zkey \
  keys/verification_key.json
```

> **Note for production:** Phase 2 ceremony should be public with multiple
> independent contributors. For MVP/testnet a single contribution is sufficient.

---

## Step 4 — Generate Verifier.sol

```bash
# snarkjs generates the Solidity verifier contract automatically
snarkjs zkey export solidityverifier \
  keys/NINIdentityProof_0001.zkey \
  contracts/Verifier.sol
```

`contracts/Verifier.sol` implements `IGroth16Verifier` from `NINNullifierRegistry.sol`.
**Deploy this contract first.**

---

## Step 5 — Local Test

```javascript
// test/identity_proof_test.js
const { groth16 } = require("snarkjs");
const { poseidon } = require("circomlib");

async function testProof() {
  // Test data — not a real NIN
  const nin_preimage       = BigInt("1234567");
  const registration_salt  = BigInt("0x" + require("crypto").randomBytes(31).toString("hex"));
  const identity_secret    = BigInt("0x" + require("crypto").randomBytes(31).toString("hex"));

  // Reconstruct commitment (same logic as NINCommitment.circom)
  const nin_key    = poseidon([nin_preimage, registration_salt]);
  const commitment = poseidon([nin_key, identity_secret]);

  // Single-leaf Merkle tree for testing
  const path_elements = new Array(20).fill(BigInt(0));
  const path_indices  = new Array(20).fill(0);
  const merkle_root   = commitment;

  const session_id = BigInt(1);

  const input = {
    nin_preimage:       nin_preimage.toString(),
    registration_salt:  registration_salt.toString(),
    identity_secret:    identity_secret.toString(),
    path_elements:      path_elements.map(x => x.toString()),
    path_indices:       path_indices,
    merkle_root:        merkle_root.toString(),
    external_nullifier: session_id.toString(),
  };

  const { proof, publicSignals } = await groth16.fullProve(
    input,
    "build/NINIdentityProof_js/NINIdentityProof.wasm",
    "keys/NINIdentityProof_0001.zkey"
  );

  console.log("Nullifier:", publicSignals[2]);

  const vKey    = require("../keys/verification_key.json");
  const isValid = await groth16.verify(vKey, publicSignals, proof);
  console.log("Proof valid:", isValid); // expected: true
}

testProof();
```

Run the test:
```bash
node test/identity_proof_test.js
```

Expected output: `Proof valid: true`

---

## Step 6 — Deploy to Sepolia Testnet

```bash
# 1. Deploy Verifier.sol first
npx hardhat run scripts/deploy_verifier.js --network sepolia

# 2. Deploy NINNullifierRegistry.sol
# Pass the Verifier.sol address from step 1 into the constructor
npx hardhat run scripts/deploy_registry.js --network sepolia
```

---

## Signal Privacy Reference

| Signal | Visibility | Storage |
|--------|-----------|---------|
| `nin_preimage` | private — citizen only | device only, never transmitted |
| `registration_salt` | private — citizen only | wallet / local storage |
| `identity_secret` | private — citizen only | wallet / local storage |
| `identity_commitment` | public | on-chain Merkle tree |
| `nullifier` | public | `nullifiers[sessionId]` in registry |
| `merkle_root` | public | `NINNullifierRegistry.merkleRoot` |

---

## Architecture: L0 → L1 Data Flow

```
[CITIZEN DEVICE]
  NIN (raw) — never leaves the device
    ↓ Poseidon(NIN, salt)
  nin_key
    ↓ Poseidon(nin_key, secret)
  identity_commitment ──────────────────→ [MERKLE TREE ON-CHAIN]
                                                   ↓
[DEVICE, per SESSION]                      merkle_root (public)
  NINIdentityProof circuit computes:
    - Merkle membership proof
    - session-specific nullifier
    ↓ Groth16 proof
  (nullifier, merkle_root, session_id) ──→ NINNullifierRegistry.sol
                                                   ↓
                                           verifyAndRegister()
                                                   ↓
                                           emit IdentityVerified
                                                   ↓
                                           Poll.sol → vote counted
```

---

*THE MIRROR REFLECTS • THE NOTARY BEARS WITNESS • THE MATRIX MEASURES*
