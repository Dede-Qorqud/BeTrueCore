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
└── NINNullifierRegistry.sol    — On-chain: Merkle root + nullifier registry
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
| `NINIdentityProof.circom` | Implements `_verifyRegistrationProof` — proves commitment is valid |
| `NINNullifierRegistry.sol` | Replaces the bare `usedNullifiers` mapping with ZK-verified nullifier storage |

---

## What these circuits prove (simultaneously)

**NINCommitment.circom** — registration phase:
- NIN code is hashed client-side, never sent to any server
- Commitment = `Poseidon(Poseidon(NIN, salt), secret)` — two-layer binding
- Output: `identity_commitment` → stored as leaf in on-chain Merkle tree

**NINIdentityProof.circom** — voting phase:
- Prover knows the `(NIN, salt, secret)` behind a valid Merkle leaf → `UNIQUENESS`
- Which leaf is used is not revealed → `ANONYMITY`  
- Same citizen cannot enter the same session twice (Sybil prevention) → `ANTI-SYBIL`
- Different sessions → different nullifiers → sessions are unlinkable → `UNLINKABILITY`
- Multiple choice changes within a session are **explicitly permitted** (key rotation via Poll.sol) → `ANTI-COERCION`

---

## Architecture position

```
[CITIZEN DEVICE]
  NIN (raw) — never leaves the device
    ↓ Poseidon(NIN, salt)
  nin_key
    ↓ Poseidon(nin_key, secret)
  identity_commitment ──────────────────────→ Merkle tree on-chain
                                                      ↓ merkle_root
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
npm install circomlib snarkjs
```

- `circomlib` — Poseidon hash, Mux1 selector (used in BinaryMerkleTree)
- `snarkjs` — proof generation, verification, Verifier.sol export
- Circom 2.0 compiler — [docs.circom.io](https://docs.circom.io/getting-started/installation/)

---

*THE MIRROR REFLECTS • THE NOTARY BEARS WITNESS • THE MATRIX MEASURES*
