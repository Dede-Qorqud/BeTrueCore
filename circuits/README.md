# BeTrueCore — ZK Identity Layer (L0 → L1)
## Circom Circuits — Draft v0.1

**Author:** Farman Guliyev (Safarnur) · ORCID: 0009-0004-4841-594X  
**Repository:** github.com/Dede-Qorqud/BeTrueCore  
**Status:** Draft written. Pending compilation and testnet deployment.

---

## What is this folder

This folder contains the Circom 2.0 circuits for the ZK identity layer of BeTrueCore — the cryptographic bridge between L0 (Identity) and L1 (Proofs) in the six-layer architecture.

These circuits implement the core principle:

> **«My identity is my fortress.»**  
> The NIN code is the signature. The circuit is the seal. The chain sees only the proof.

---

## Files

```
circuits/
├── NINCommitment.circom        — Registration: NIN code → ZK commitment
├── NINIdentityProof.circom     — Voting:       Merkle membership + nullifier
├── COMPILE.md                  — Step-by-step compilation and deployment guide
└── lib/
    └── BinaryMerkleTree.circom — Poseidon Merkle tree (helper library)

contracts/
├── CompositionTree.sol — On-chain: the community's composition.
│ Poseidon Merkle tree, filled by the core
│ from its own queue of registrations
└── NINNullifierRegistry.sol — On-chain: nullifier registry. Holds no root:
asks the session which root it opened with.
Accepts Groth16 ZK proofs from NINIdentityProof
```

---

## How these circuits connect to the Developer Package

The existing Developer Package (`src/`) contains `BeTrueCoreCore.sol` with this placeholder:

```solidity
function register(bytes32 identity_commitment, bytes calldata zk_proof) external {
    // ZK proof verification would be performed here
    // via Circom verifier contract (external dependency)
    // _verifyRegistrationProof(identity_commitment, zk_proof);  ← this slot
}
```

These circuits fill that slot:

| Circuit | Fills which slot |
|---------|-----------------|
| `NINCommitment.circom` | Produces `identity_commitment` that `BeTrueCoreCore` stores |
| `NINIdentityProof.circom` | Runs once per voting session: proves the commitment is a leaf under the root the session opened with, and derives a session-bound nullifier. The registry holds no root of its own since 28 November 2026 — it asks the session — which is why registration is not frozen while a session runs |
| `NINNullifierRegistry.sol` | Replaces the bare `usedNullifiers` mapping with ZK-verified nullifier storage |

---

## What these circuits prove (simultaneously)

**NINCommitment.circom** — registration phase:
- NIN code is hashed client-side, never sent to any server
- Commitment = `Poseidon(Poseidon(NIN, salt), secret)` — two-layer binding
- Output: `identity_commitment` → a leaf of the composition tree, which is built ON CHAIN by `contracts/CompositionTree.sol` from a queue `BeTrueCoreCore` keeps itself. That the root carries exactly the commitments registered, and nothing else, was the primitive marked `not established` in the requirements table of `docs/AUTHORITY_CHAIN.md`, §14; it was established in code on 28 November 2026 and the table says so. A reader holding the event log and nothing else rebuilds the tree and arrives at the root. What a closed roster still rests on is a different thing entirely — that one commitment is one person, which no part of this rests on proof

**NINIdentityProof.circom** — voting phase. Each line states what the circuit
establishes, and the label names that and nothing wider:

- Prover knows the `(NIN, salt, secret)` behind a valid Merkle leaf → `MEMBERSHIP`. That one leaf corresponds to one person is not established by the circuit, and is not established anywhere else either: one human who generates two secrets holds two provable commitments. What has changed since this line was first written is what it no longer rests on — since 25 November 2026 `register` verifies a Groth16 proof on-chain, and since 28 November the root is computed on-chain. What remains is the identifier checked at the e-government gateway, in the client, and it is an organisational guarantee.
- Which leaf is used is not revealed → `LEAF PRIVACY`. Not anonymity in the legal sense — the tree of commitments is pseudonymisation, and pseudonymised data remains personal data (`docs/AUTHORITY_CHAIN.md`, §11).
- The same nullifier cannot be spent twice in one session → `ONE ENTRY PER SESSION`. Sybil resistance is a different property and rests elsewhere: on the identifier checked at the e-government gateway, in the client, outside this protocol. It is an organisational guarantee and is named as one.
- Different sessions → different nullifiers → `NULLIFIERS DO NOT LINK SESSIONS`. The link that remains is the sending address: one wallet links that person's sessions whatever the nullifier scheme does (§11, *No Linkage*, partial correspondence).
- Multiple choice changes within a session are **explicitly permitted** (key rotation via Poll.sol) → `EARLIER CHOICE UNPROVABLE`. This is not resistance to coercion. It makes an earlier choice prove nothing afterwards; a coercer who watches the moment of choosing, or who holds the message key, is untouched by it (`docs/AUTHORITY_CHAIN.md`, §12).

---

## Architecture position

```
[CITIZEN DEVICE]
  NIN (raw) — never leaves the device
    ↓ Poseidon(NIN, salt)
  nin_key
    ↓ Poseidon(nin_key, secret)
  identity_commitment ──────────────────────→ [COMPOSITION TREE — ON CHAIN]
                                               CompositionTree.sol, filled by
                                               the core from its own queue
                                                      ↓ root, snapshotted when
                                                        a session opens
[DEVICE, per SESSION]                         NINNullifierRegistry.sol
  NINIdentityProof circuit                          ↓ verifyAndRegister()
    ↓ Groth16 proof                           proof valid + nullifier fresh
  (nullifier, merkle_root, session_id) ──→          ↓
                                             BeTrueCoreCore.sol
                                                      ↓
                                             Poll.sol → choice submitted
                                                      ↓ (time lock)
                                             VWUEngine.sol → weight updated
```

---

## Status and next steps

| Step | Status |
|------|--------|
| Circuit design | ✅ Complete |
| Circom 2.0 code | ✅ Written (v0.1) |
| Compilation (`circom --r1cs --wasm`) | ⬜ Pending — needs dev environment |
| Trusted setup (ptau + phase 2) | ⬜ Pending |
| `Verifier.sol` generation (snarkjs) | ⬜ Pending — generated after trusted setup |
| Testnet deployment (Sepolia) | ⬜ Pending |
| Integration test with `BeTrueCoreCore.sol` | ⬜ Pending |

See `circuits/COMPILE.md` for the full compilation and deployment guide.

---

## Dependencies

```bash
npm install circomlib circomlibjs snarkjs
```

- `circomlib` — Poseidon hash, Mux1 selector (used in BinaryMerkleTree); a `.circom` library, reached at compile time through `-l node_modules`
- `circomlibjs` — the JavaScript implementation of Poseidon, used by the test script. It is a separate package on purpose: `circomlib` exports nothing from JavaScript, so `require("circomlib").poseidon` is undefined
- `snarkjs` — proof generation, verification, Verifier.sol export
- Circom 2.0 compiler — [docs.circom.io](https://docs.circom.io/getting-started/installation/)

---

*THE MIRROR REFLECTS • THE NOTARY BEARS WITNESS • THE MATRIX MEASURES*
