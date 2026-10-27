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

# circomlib   — the .circom circuit library, used by -l node_modules at compile time
# circomlibjs — the JavaScript implementation of Poseidon, used by the test script.
#               circomlib exports NOTHING from JavaScript: its index.js is empty,
#               so require("circomlib").poseidon is undefined.
npm install circomlib circomlibjs snarkjs
```

The contracts are a Foundry project — see `foundry.toml` at the repository
root and the test suite in `test/`. Deployment in Step 6 therefore uses
`forge` and `cast`, and no JavaScript deployment framework is installed here.

---

## Step 2 — Compile NINIdentityProof Circuit

```bash
# Compile circuit → R1CS + WASM + SYM
# -l node_modules: path to circomlib
# --inspect: runs the compiler's additional check over the produced constraints
#            and names any signal that appears in no constraint (warning CA01).
#            Without this flag the compiler says nothing and prints
#            "Everything went okay" in that case too. Not optional for an audit.
circom circuits/NINIdentityProof.circom \
  --r1cs \
  --wasm \
  --sym \
  --inspect \
  -l node_modules \
  -o build/

# Record the constraint count on the first successful compilation and compare
# every later build against it. The circuits have not been compiled yet, so
# there is no measured figure to put here.
# What the source fixes, and what must hold on that first build:
#   1 public output (nullifier), 2 public inputs (merkle_root, external_nullifier)
#   43 private inputs (3 secrets + 20 path elements + 20 path indices)
# A later count far from the first one means the circuit itself changed — find
# out why before going on.
snarkjs r1cs info build/NINIdentityProof.r1cs
```

**For pilot (50–100 participants)** — change the last line of `NINIdentityProof.circom`:
```circom
// Change LEVELS from 20 to 7:
component main {public [merkle_root, external_nullifier]} = NINIdentityProof(7);
// LEVELS=7 supports up to 128 participants, faster proof generation
```

> **The depth is part of the definition of the root.** The same set of
> participants hashed at another depth yields another root, every precomputed
> path stops matching, and every proof already issued becomes invalid. So the
> depth never changes here alone: it changes in three places at once — this
> circuit, the off-chain tree builder, and the root written into the registry —
> and only while registration is stopped, because the registry holds a single
> root and accepts no earlier ones. The test script below carries the same
> number; change it there too.

---

## Step 3 — Trusted Setup (Powers of Tau)

Groth16 requires a trusted setup. For testnet/pilot we use
the Hermez public ceremony (BN254 curve, ~100M participants).

```bash
# Download the ptau file from the Hermez public ceremony.
# final_15 covers circuits up to 2^15 = 32,768 constraints. Check the count
# that snarkjs r1cs info prints in Step 2 against that ceiling before running
# setup: a circuit above it needs a larger ptau, and setup fails outright.
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

> **Note on the ceremony — read this before the first real session.** The
> Phase 2 contribution is what makes the setup safe. With a single
> contributor, that contributor keeps the secret material of the setup and can
> forge a valid proof for this circuit — a membership proof for a leaf that is
> not in the tree, that is, a participant who does not exist. Nothing on-chain
> can tell such a proof from an honest one.
>
> A single contribution is therefore acceptable only while the deployment is a
> test with no real community behind it. Before the first session with real
> participants, the Phase 2 ceremony must be public, with several independent
> contributors, and the deployed verifier must be the one built from it.
>
> This is one of three doors into the roster, and they are listed together
> here because closing one and leaving the others open changes nothing.
> First, this ceremony: a single contributor can forge a membership proof for
> a leaf that is not in the tree. Second, the registry root: it is written by
> one address, the tree is built off-chain, and a root carrying a leaf nobody
> chose verifies exactly as well as an honest one. Third, and widest,
> `register` in `src/BeTrueCoreCore.sol`: it is external and unguarded, any
> address may call it with any 32-byte value, the proof argument is accepted
> and never read, and the number of calls is bounded by nothing — so there an
> extra entry costs one call to anyone at all, while the first two doors are
> reachable by one party each.
>
> What the roster actually rests on is therefore organisational and lies
> outside cryptography: the client that is supposed to check the number at the
> e-government gateway, and whoever computes the tree root. Name it as
> organisational wherever Sybil-resistance is claimed for L0. The
> cryptographic piece that is missing is named precisely: a
> third-party-verifiable proof that a root transition inserted exactly the
> announced commitments and nothing else, disclosing no counts — the
> `not established` row of the requirements table.

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
const { buildPoseidon } = require("circomlibjs");

const LEVELS = 20; // must equal the LEVELS of the compiled circuit

async function testProof() {
  // Poseidon lives in circomlibjs and is built asynchronously.
  // circomlib itself exports nothing from JavaScript.
  const poseidon = await buildPoseidon();
  const H = (a, b) => poseidon.F.toObject(poseidon([a, b]));

  // Test data — not a real NIN
  const nin_preimage      = BigInt("1234567");
  const registration_salt = BigInt("0x" + require("crypto").randomBytes(31).toString("hex"));
  const identity_secret   = BigInt("0x" + require("crypto").randomBytes(31).toString("hex"));

  // Reconstruct the leaf (the same two layers as NINCommitment.circom)
  const nin_key    = H(nin_preimage, registration_salt);
  const commitment = H(nin_key, identity_secret);

  // Merkle path: the leaf sits at the far left, every sibling is zero.
  // The root is NOT the commitment — it is the commitment hashed upward LEVELS
  // times. Setting merkle_root = commitment makes the root constraint inside
  // lib/BinaryMerkleTree.circom fail, and fullProve throws instead of proving.
  const path_elements = new Array(LEVELS).fill(BigInt(0));
  const path_indices  = new Array(LEVELS).fill(0);

  let node = commitment;
  for (let i = 0; i < LEVELS; i++) {
    node = H(node, path_elements[i]); // index 0 → node is the left child
  }
  const merkle_root = node;

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

  // publicSignals holds outputs first, then public inputs:
  //   [0] nullifier (the circuit's output)
  //   [1] merkle_root
  //   [2] external_nullifier
  console.log("Nullifier:  ", publicSignals[0]);
  console.log("Merkle root:", publicSignals[1]);
  console.log("Session:    ", publicSignals[2]);

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
# This repository holds no scripts/ directory and no JavaScript deployment
# framework. The contracts are built and deployed with Foundry. Note that
# contracts/ sits outside src/, so it builds under its own profile:
#   FOUNDRY_PROFILE=contracts forge build

export SEPOLIA_RPC_URL=...   # your Sepolia endpoint
export DEPLOYER_KEY=...      # private key of the deploying address

# 1. Deploy the snarkjs-generated verifier first.
# Open contracts/Verifier.sol and read the contract name before running this:
# recent snarkjs emits `Groth16Verifier`, older versions emit `Verifier`.
forge create contracts/Verifier.sol:Groth16Verifier \
  --rpc-url "$SEPOLIA_RPC_URL" --private-key "$DEPLOYER_KEY" --broadcast

# 2. Deploy NINNullifierRegistry with the verifier address and the first root.
# The constructor refuses a zero root and a root outside the BN254 scalar
# field, so the root of the tree participants were registered into must exist
# before this call — it is a constructor argument, not a later step.
forge create contracts/NINNullifierRegistry.sol:NINNullifierRegistry \
  --rpc-url "$SEPOLIA_RPC_URL" --private-key "$DEPLOYER_KEY" --broadcast \
  --constructor-args "$VERIFIER_ADDRESS" "$INITIAL_ROOT"

# 3. Wire the registry to Poll.sol.
# Until this is done, verifyAndRegister reverts with OnlyPoll and nobody can
# enter a session. Deployment is not finished without it.
cast send "$REGISTRY_ADDRESS" "setPoll(address)" "$POLL_ADDRESS" \
  --rpc-url "$SEPOLIA_RPC_URL" --private-key "$DEPLOYER_KEY"

# 4. After each later registration batch, write the new root.
# A proof is valid only against the root the registry holds at that moment,
# which is why registration stays frozen for the duration of a session.
cast send "$REGISTRY_ADDRESS" "updateMerkleRoot(bytes32)" "$NEW_ROOT" \
  --rpc-url "$SEPOLIA_RPC_URL" --private-key "$DEPLOYER_KEY"
```

---

## Signal Privacy Reference

| Signal | Visibility | Storage |
|--------|-----------|---------|
| `nin_preimage` | private — citizen only | device only, never transmitted |
| `registration_salt` | private — citizen only | wallet / local storage |
| `identity_secret` | private — citizen only | wallet / local storage |
| `identity_commitment` | public | leaf of a tree built off-chain; only the root is stored on-chain |
| `nullifier` | public | `nullifiers[sessionId]` in registry |
| `merkle_root` | public | `NINNullifierRegistry.merkleRoot` |

**What the three private signals amount to (audit lens B6).** The first three
rows are not merely confidential: together they are the participant's entry
ticket. Anyone holding `nin_preimage`, `registration_salt` and
`identity_secret` builds a valid proof and enters the session in that
participant's place. The nullifier is `Poseidon(identity_secret, session_id)`
and is therefore the same value whoever computes it, so the registry records
one entry and cannot tell which of the two produced it. A coercer who obtains
these three values has no need to watch the participant at all.

Nothing in this guide and nothing in the protocol prevents that handover: key
material is held by the participant and is transferable by the participant.
The election literature closes this case with a fake key the coercer cannot
distinguish from a real one (Juels, Catalano and Jakobsson, *Coercion-Resistant
Electronic Elections*, Cryptology ePrint Archive 2002/165); no such primitive
is established here. One layer up the same holds for a different key — the
ephemeral message key of `Poll.sol`, which is what overrides an earlier choice.

Two consequences for the pilot. The onboarding material states plainly that
these three values are shown to no one, on the same footing as it states that
the NIN never leaves the device. And the boundary claim is not widened
anywhere: a defector is not identified, inside the protocol perimeter,
provided each participant chooses once and with their own key. See
`WHITEPAPER.md` 5.7 and `docs/AUTHORITY_CHAIN.md` §12.

---

## Architecture: L0 → L1 Data Flow

```
[CITIZEN DEVICE]
  NIN (raw) — never leaves the device
    ↓ Poseidon(NIN, salt)
  nin_key
    ↓ Poseidon(nin_key, secret)
  identity_commitment ──────────────────→ [MERKLE TREE — BUILT OFF-CHAIN]
                                           only its root is written on-chain
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