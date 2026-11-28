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
# Node.js 20 LTS required. package.json and package-lock.json are in this
# repository, so there is nothing to initialise and nothing to choose: npm ci
# installs exactly what the lock file records, and fails outright if the two
# files disagree. Never npm init or npm install here — either one floats the
# versions again.
npm ci

# circomlib   — the .circom circuit library, used by -l node_modules at compile time
# circomlibjs — the JavaScript implementation of Poseidon, used by the test script.
#               circomlib exports NOTHING from JavaScript: its index.js is empty,
#               so require("circomlib").poseidon is undefined.
#
# Pinned: circomlib 2.0.5, circomlibjs 0.1.7, snarkjs 0.7.6. Every figure in
# Step 2 was measured with these, on 25 November 2026, and the circuit still
# compiles to the same 11,951 constraints after a clean npm ci.
#
# Why these three are pinned where a Node project usually floats: circomlib
# defines Poseidon inside the circuit, circomlibjs defines it outside, and the
# tree root is built with the second while every proof is built against the
# first. They must agree to the digit. circomlib already ships
# poseidon_old.circom beside poseidon.circom, so that hash has changed once
# before. Drift does not break the build — the circuit compiles, the constraint
# count holds, the test suite passes — and surfaces only as an on-chain
# verification that fails for no visible reason. Raising a version is therefore
# a deliberate act: raise it, re-run Steps 2-4, re-check the counts.
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

# First successful compilation: 24 November 2026, circom 2.2.3, this guide's
# Steps 1-2 with --inspect. Both depths were built.
# Measured at LEVELS = 20: 11,951 constraints (5,649 non-linear + 6,302 linear),
#   11,976 wires, 18,073 labels, curve BN254, and the figures the source fixes:
#   1 public output (nullifier), 2 public inputs (merkle_root, external_nullifier),
#   43 private inputs (3 secrets + 20 path elements + 20 path indices).
# Measured at LEVELS = 7 (pilot): 5,191 constraints (2,451 + 2,740), 5,203 wires,
#   7,829 labels, 17 private inputs (3 secrets + 7 path elements + 7 path indices).
# --inspect raised no CA01 warning at either depth.
# Compare every later build against the figure for the depth it was built at.
# A count far from it means the circuit itself changed — find out why before
# going on.
snarkjs r1cs info build/NINIdentityProof.r1cs
```

**Depth is settled: LEVELS stays at 20**, pilot included. Decided 24 November
2026, once the first compilation had measured both: 11,951 constraints at depth
20 against 5,191 at depth 7. Depth 20 costs about twice the proving time on the
participant's device and about twice the size of the proving key, and costs
nothing at all in proof size, in gas, or in on-chain verification. It holds
1,048,576 participants where depth 7 holds 128, and changing depth after launch
is a restart of the registry rather than an edit — see the note below.

The alternative is kept here for reference only, and is NOT in use:
```circom
// NOT IN USE. LEVELS = 7 supports up to 128 participants:
component main {public [merkle_root, external_nullifier]} = NINIdentityProof(7);
```

> **The depth is part of the definition of the root.** The same set of
> participants hashed at another depth yields another root, every precomputed
> path stops matching, and every proof already issued becomes invalid. So the
> depth never changes here alone: it changes in three places at once — this
> circuit, the off-chain tree builder, and the root written into the registry —
> and only while registration is stopped, because the registry holds a single
> root and accepts no earlier ones. The test script below carries the same
> number; change it there too.

**LEVELS is not the seven-step cycle and not the message limit.** Three numbers
in this project look alike and mean different things. They are set out together
here because confusing them is easy and the consequences are not:

| Number | What it is | Where it lives |
|---|---|---|
| 7 steps | one prompt, three agenda choices, three dilemma choices | `steps_completed` (0-7) and `AGENDA_TOPICS = 3` in `src/` |
| 20 messages | how many times one participant may resubmit a choice within a session, before the time lock | `maxMessages = 20`, `docs/MACI_ENGINEER_PACKAGE.md` |
| LEVELS = 20 | the depth of the composition tree, that is the ceiling on participants: 2^20 = 1,048,576 | this file and the last line of `NINIdentityProof.circom` |

LEVELS says nothing about how a session runs. It says how many people fit in
one community. The two other numbers say nothing about the tree.

---

## Step 2b — Compile NINCommitment Circuit

The registration circuit, and a separate step because it is a separate circuit:
its own key, its own verifier, its own public signal. `register` in
`src/BeTrueCoreCore.sol` reads a proof of this one, never of the voting circuit.

```bash
circom circuits/NINCommitment.circom \
  --r1cs \
  --wasm \
  --sym \
  --inspect \
  -l node_modules \
  -o build/commitment/

# First successful compilation: 25 November 2026, circom 2.2.3, this step with
# --inspect. Measured: 1,034 constraints (486 non-linear + 548 linear),
#   1,038 wires, 1,540 labels, curve BN254, and the figures the source fixes:
#   1 public output (identity_commitment), 0 public inputs,
#   3 private inputs (nin_preimage, registration_salt, identity_secret).
# --inspect raised no CA01 warning: "Everything went okay".
# No depth enters this circuit. It hashes three values and has no tree, so the
# count does not move with LEVELS and there is nothing here to rebuild when the
# composition tree changes.
snarkjs r1cs info build/commitment/NINCommitment.r1cs
```

**The one public signal is the commitment.** `NINCommitment` declares no public
input, and circom makes an output signal public by the definition of the
language, so the public list is exactly `[identity_commitment]` —
`build/commitment/NINCommitment.sym`, witness 1 = `main.identity_commitment`.
The verifier of Step 4b therefore takes `uint[1]` where the voting circuit's
takes `uint[3]`: the two verifiers are not interchangeable, and the compiler
says so rather than letting one stand in for the other.

**What a proof of this circuit says, and what it does not.** It says its prover
knew a `nin_preimage`, a `registration_salt` and an `identity_secret` whose
Poseidon chain equals the commitment. It does not say that the number inside was
ever shown to the e-government gateway, and it binds nothing to an address. One
person who generates two secrets holds two provable commitments. So this proof
closes the free entry under a commitment nobody holds the preimages of, and
Sybil-resistance at L0 stays organisational — name it as organisational
wherever it is claimed.

---

## Step 3 — Trusted Setup (Powers of Tau)

Groth16 requires a trusted setup. For testnet/pilot we use
the Hermez public ceremony (BN254 curve, ~100M participants).

```bash
# Download the ptau file from the Hermez public ceremony.
# final_15 covers circuits up to 2^15 = 32,768 constraints. Measured in Step 2:
# 11,951 constraints at LEVELS = 20 and 5,191 at LEVELS = 7, so this file covers
# both, with room to spare — the smallest that would serve is degree 14 and
# degree 13 respectively. Re-check the count against the ceiling whenever the
# circuit changes: a circuit above it needs a larger ptau, and setup fails
# outright.
#
# Hermez's own buckets stopped serving the file in September 2026: the S3 one
# answers AccessDenied, storage.googleapis.com/zkevm/ptau answers 403. The
# ceremony is unchanged — only the download moved. Any mirror will do, because
# the two checks after the download identify the file instead of trusting the
# host: its size, and the blake2b-512 that snarkjs publishes for it. A copy that
# fails either check is not this ceremony's: stop, and find another.
# Downloaded and checked this way on 25 November 2026.
curl -L https://github.com/hilawe/dash-mno-verify/releases/download/ptau-hermez-v1/powersOfTau28_hez_final_15.ptau \
     -o pot15_final.ptau
stat -c %s pot15_final.ptau   # expected: 37831832
b2sum pot15_final.ptau        # blake2b-512, expected:
# 982372c867d229c236091f767e703253249a9b432c1710b4f326306bfa2428a17b06240359606cfe4d580b10a5a1f63fbed499527069c18ae17060472969ae6e

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
> participants the ceremony must be run again, and the shape it has to take
> follows from what this protocol is rather than from cryptographic custom.
> Groth16 needs ONE honest contributor, not a quorum: the security holds if a
> single participant destroyed their share. So what matters is not how many
> contributed but that no one could have been kept out. A ceremony with a
> named set of contributors would be a declared membership of exactly the kind
> this architecture refuses everywhere else, and it would place in one group's
> hands something larger than any role here holds — whoever keeps a share can
> forge a membership proof for a leaf that is not in the tree, and no root, no
> tree and no registry can tell. The ceremony is therefore to be open to
> anyone, with its transcript published, so that each contribution can be
> checked by anyone against the one before it. That the community runs it is
> not a slogan: it is the same move the rest of the protocol makes — not a
> body that announces who belongs, but a procedure whose record is checkable.
>
> The loop in this, said plainly rather than left for a reader to find: the
> ceremony happens BEFORE the community exists, because the verifier must be
> deployed before anyone can register. There is no roster to draw contributors
> from. Open entry is what cuts the loop — participation needs no proof of
> belonging, and the transcript is checkable without knowing who anybody was.
>
> This is one of three doors into the roster, and they are listed together
> here because closing one and leaving the others open changes nothing.
> First, this ceremony: a single contributor can forge a membership proof for
> a leaf that is not in the tree. Second, the registry root — CLOSED on 28
> November 2026, and named here rather than struck out, because a reader who
> finds two doors cannot tell which three were meant. It used to be written
> by one address, over a tree assembled off-chain, and a root carrying a leaf
> nobody chose verified exactly as well as an honest one. The registry now
> holds no root at all: it asks the session which root that session opened
> with, and that root was computed on-chain by `contracts/CompositionTree.sol`
> from the core's own queue of registrations. `updateMerkleRoot` no longer
> exists, so there is no address to trust not to use it. Third, `register` in
> `src/BeTrueCoreCore.sol` — until 25 November 2026 the widest of the three,
> and now the narrowest. It used to be unguarded: any address could call it
> with any 32-byte value, the proof argument was accepted and never read, and
> the number of calls was bounded by nothing, so an extra entry cost one call
> to anyone at all. Since then it verifies a proof of NINCommitment against the
> commitment being registered (Steps 2b and 4b), so an extra entry costs a
> proof. No ceiling on the roster was added and none is to be: a limit on the
> size of a community would turn size from a reading into a norm. What keeps
> an extra entry from being worth making is the rule by which weight arises,
> not a count. What it still does not do, and no
> version of it could: tell two commitments made by one person from two made by
> two people. So the first two doors stand open and reachable by one party
> each, the third now costs a proof, and the roster is not closed by any of
> this.
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

## Step 4b — Generate RegistrationVerifier.sol

The same four commands as Step 3 and Step 4, over the registration circuit.
Run them after Step 2b, and before deploying `BeTrueCoreCore`.

```bash
snarkjs groth16 setup \
  build/commitment/NINCommitment.r1cs \
  pot15_final.ptau \
  keys/NINCommitment_0000.zkey

# Required. Without a contribution the setup is cryptographically unsafe.
snarkjs zkey contribute \
  keys/NINCommitment_0000.zkey \
  keys/NINCommitment_0001.zkey \
  --name="BeTrueCore registration contribution" -v

snarkjs zkey verify \
  build/commitment/NINCommitment.r1cs \
  pot15_final.ptau \
  keys/NINCommitment_0001.zkey          # expect: ZKey Ok!

snarkjs zkey export verificationkey \
  keys/NINCommitment_0001.zkey \
  keys/registration_vkey.json

snarkjs zkey export solidityverifier \
  keys/NINCommitment_0001.zkey \
  contracts/RegistrationVerifier.sol
```

**Then rename the contract, and rename nothing else.** snarkjs names every
verifier it exports `Groth16Verifier`, and `contracts/Verifier.sol` from Step 4
already holds that name; two contracts under one name in one project collide.
Open `contracts/RegistrationVerifier.sol` and change its single declaration
line to `contract RegistrationVerifier {`. That rename is the only edit this
file takes, and a regeneration brings the generated name back — rename it
again, and leave everything else exactly as generated. Do not rename the
committed `contracts/Verifier.sol`: no name here carries cryptographic weight,
and that file is already tested and referenced by name.

**One ptau for both circuits.** By the rule of Step 3 — the smallest degree
whose 2^k covers the count — 1,034 constraints need degree 11 where the voting
circuit needs 14, so `pot15_final.ptau` covers both with room to spare.

**The ceremony note of Step 3 applies here unchanged,** and for this circuit it
reads: a single Phase 2 contributor can forge a proof for a commitment whose
preimages nobody knows, which is an entry in the roster behind which there is
no one. Acceptable only while the deployment is a test with no real community
behind it; before the first session with real participants, run Phase 2 in
public with several independent contributors and deploy the verifier built from
that run.

**Where the address goes.** `contracts/RegistrationVerifier.sol` implements
`IRegistrationVerifier`, declared in `src/BeTrueCoreCore.sol`. The address is a
constructor argument of `BeTrueCoreCore` and there is no setter for it — a
setter would be a role able to point registration at a verifier that accepts
anything. So this verifier is deployed before the core contract, and a
constructor given the zero address is refused outright.

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

# 2. Deploy NINNullifierRegistry with the verifier and the core.
# It takes no root. Since 28.11.2026 it holds none: it asks the session which
# root that session opened with, and that root was computed on-chain by the
# composition tree. BeTrueCoreCore must therefore already exist — it is
# deployed in the checklist of docs/MACI_ENGINEER_PACKAGE.md, which this
# section assumes has been run up to that point. Both addresses are refused
# as zero here rather than at the first entry.
forge create contracts/NINNullifierRegistry.sol:NINNullifierRegistry \
  --rpc-url "$SEPOLIA_RPC_URL" --private-key "$DEPLOYER_KEY" --broadcast \
  --constructor-args "$VERIFIER_ADDRESS" "$CORE_ADDRESS"

# 3. Wire the registry to Poll.sol.
# Until this is done, verifyAndRegister reverts with OnlyPoll and nobody can
# enter a session. Deployment is not finished without it.
cast send "$REGISTRY_ADDRESS" "setPoll(address)" "$POLL_ADDRESS" \
  --rpc-url "$SEPOLIA_RPC_URL" --private-key "$DEPLOYER_KEY"

# THERE IS NO STEP FOR WRITING A ROOT, and there is no function to call.
# updateMerkleRoot was removed on 28.11.2026 together with the root it wrote.
# Nothing has to be done after a registration batch for proofs to keep
# verifying, and registration is NOT frozen for the duration of a session:
# the session holds the root it opened with, the tree goes on growing beside
# it, and a proof built at the start of a session is as good at its end.

# 4. Deploy circomlib's two-input Poseidon from its generated bytecode.
# The composition tree hashes with it and it must be the Poseidon the
# circuits use. There is no Solidity source: the recipe for printing the
# bytecode is in test/PoseidonT3Bytecode.sol, and `cast send --create` sends
# it as a plain creation transaction.
cast send --create "$POSEIDON_CREATION_BYTECODE" \
  --rpc-url "$SEPOLIA_RPC_URL" --private-key "$DEPLOYER_KEY"

# 5. Deploy the composition tree with that hasher and the core as registrar.
# BeTrueCoreCore takes no tree in its constructor and the tree takes the
# core's address in its own, so the core exists first and this order cannot
# be reversed. A zero address is refused here, not at the first insertion.
forge create contracts/CompositionTree.sol:CompositionTree \
  --rpc-url "$SEPOLIA_RPC_URL" --private-key "$DEPLOYER_KEY" --broadcast \
  --constructor-args "$POSEIDON_ADDRESS" "$CORE_ADDRESS"

# 6. Wire the tree into the core. Once, and never again.
# Refused unless the tree names this core as its registrar, so a mistyped
# address cannot be wired. Until it is done openSession reverts, so a
# deployment that forgets this step fails loudly rather than snapshotting an
# empty root. What the check cannot establish is that this tree is the
# community's own rather than an empty one built to pass it; the published
# address is what a reader checks.
cast send "$CORE_ADDRESS" "setCompositionTree(address)" "$TREE_ADDRESS" \
  --rpc-url "$SEPOLIA_RPC_URL" --private-key "$DEPLOYER_KEY"

# 7. Write registrations into the tree on a cadence, not after each entrant.
# The call takes no list of commitments: leaves are drawn from the core's own
# queue, from the front, in registration order, so the coordinator decides
# when a batch is written and never who is in it. The argument bounds the
# size of a batch; 0 means everything waiting. A call per entrant would show
# an observer one person entering alone, which is what batching is for.
cast send "$CORE_ADDRESS" "commitRegistrationsToTree(uint256)" 0 \
  --rpc-url "$SEPOLIA_RPC_URL" --private-key "$COORDINATOR_KEY"
```

---

## Signal Privacy Reference

| Signal | Visibility | Storage |
|--------|-----------|---------|
| `nin_preimage` | private — citizen only | device only, never transmitted |
| `registration_salt` | private — citizen only | wallet / local storage |
| `identity_secret` | private — citizen only | wallet / local storage |
| `identity_commitment` | public | leaf of two trees: the composition tree, built on-chain by `contracts/CompositionTree.sol` from the core's queue, and the off-chain tree whose root the registry holds. Public because it arrives as an argument of `register`, so it is seen in the mempool and kept in the chain's history; the same value for one person in every community, which is what the per-community tag of preprint [14] §5.5 exists to replace |
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
