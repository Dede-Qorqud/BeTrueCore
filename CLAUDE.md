# CLAUDE.md

Working notes for anyone — human or AI agent — editing this repository.

This file is public. Nothing from the master document belongs here.

---

## 1. What this repository is

BeTrueCore is a cryptographic protocol for collective decision-making in which
the participant is not named and the decision is verifiable. Six layers:

| Layer | What it does | State |
|---|---|---|
| L0 — Identity | NIN-code + MPC; the identifier never leaves the device | circuits drafted, MPC not integrated |
| L1 — Proofs | zk-SNARKs, Circom/Groth16, anti-collusion pattern | circuits drafted v0.1, no verifier deployed |
| L2 — Execution | Optimism; session lifecycle and VWU accounting | contracts written, not deployed |
| L3 — Lock | Lit Protocol time-lock | not integrated |
| L4 — Archive | Celestia DA | not integrated |
| L5 — AI Agents | Analyst ×3, Strategist ×3, Sentinel ×3 — read-only | specified, not implemented |

Stage: TRL 2 → TRL 3. The contracts compile and the test suite passes; nothing
is deployed, and three named gaps are open (section 7).

What is here:

```
src/              IBeTrueCore, IBeTrueCoreAntiCollusion, BeTrueCoreCore,
                  Poll, EthicalMatrix, HarmonyAgent, VWUEngine
contracts/        NINNullifierRegistry  (outside src/ — separate build profile)
circuits/         NINCommitment.circom, NINIdentityProof.circom,
                  lib/BinaryMerkleTree.circom, COMPILE.md, README.md
test/             BeTrueCore.t.sol — 38 tests
docs/             ARCHITECTURE_FOUNDATION, AUTHORITY_CHAIN, MAPPING_MODEL,
                  MACI_ENGINEER_PACKAGE, L5_MANAGED_AGENTS
```

---

## 2. Build and test

```bash
forge test            # src/ + test/ — 38 tests, all passing
forge build           # src/ only
FOUNDRY_PROFILE=contracts forge build    # contracts/ — separate profile
```

`contracts/` sits outside `src/` and builds under its own profile in
`foundry.toml`. A plain `forge build` does not touch it.

Toolchain, fixed in `foundry.toml`: Solidity 0.8.24, EVM `shanghai`, optimizer
on at 200 runs. Every contract declares `pragma solidity ^0.8.24`.

**Before the first run.** The test suite imports `forge-std/Test.sol`, and
`forge-std` is not vendored here. Install it once in the clone:

```bash
forge install foundry-rs/forge-std
```

Without it the build stops at line 4 of `test/BeTrueCore.t.sol`. The version is
therefore not pinned by this repository; if a future `forge-std` breaks the
build, pin it here as a submodule.

Two `lib/` directories exist and they serve different toolchains. `lib/` at the
root is Foundry's, declared by `libs = ["lib"]` in `foundry.toml`, and holds
`forge-std`. `circuits/lib/` is circom's and holds `BinaryMerkleTree.circom`,
which `NINIdentityProof.circom` includes by the relative path
`./lib/BinaryMerkleTree.circom`. Neither toolchain sees the other's directory.

Circuits are compiled separately — see `circuits/COMPILE.md`. They need
`circomlib`, `circomlibjs` and `snarkjs` from npm. No JavaScript deployment
framework is used anywhere: deployment is `forge create` and `cast send`.

---

## 3. Boundaries a code change must not cross

These are not style preferences. Each one is load-bearing, and a change that
breaks one changes what the protocol claims.

**The verdict is not the AI's.** The decision is made of votes. An agent
observes and reports; its report is testimony the chain checks against the map.
The `Decides` column in every agent table reads `NEVER`, and that is
architectural, not a policy statement.

**L5 reads L4 and nothing else.** One read-only gateway over the archive. No
agent reaches another layer directly, and no agent holds a write path to any
layer. Giving an agent a second source, or any write endpoint, is out of scope
for a patch — it is a change of architecture.

**No biometrics, anywhere.** Identity is proven by the national identifier
through a commitment computed on the device. The word does not belong in this
codebase, including in comments and examples.

**The weight floor is non-burnable.** `VWU_BASE` is the floor and
`VWUEngine._apply` enforces it. Nothing other than a negative session
contribution lowers a rating — see the rational filter below. Absence never
lowers one: it freezes.

**Silence is a recorded state.** Never an abstention, never missing data, never
a third button. It carries a count and a weight sum of its own in every result.

**The traffic light is applied separately to Option A and to Option B** — one
and the same map, one and the same thresholds, a colour of its own for each
side. Silence receives no colour, and the weight behind it is added to neither
side.

**The Panorama accounts for the whole roster.** Three rows — Option A, Option B,
silence — and the head above them is their sum, by people and by weight alike.
The head is not stored on chain. `finalizeSession` refuses a result whose rows
do not add up (`"Rows do not account for the roster"`), and
`applySessionParticipation` refuses a list that does not cover it
(`"List does not cover the roster"`). Both checks are tested; do not relax
either to make a fixture pass.

**Roles change hands in two steps.** The holder nominates, the nominee accepts.
`BeTrueCoreCore`, `Poll`, `EthicalMatrix`, `HarmonyAgent`, `VWUEngine` and
`NINNullifierRegistry` all follow this shape. A one-step setter would hand the
role to a mistyped address with no way back.

---

## 4. Vocabulary

`[PROTECTED]` marks a declaration whose name and type are public while the
operative value lives in the master document. The marker goes on the line it
applies to, because a number without one reads as operative. Do not call such a
place a stub, a placeholder, or a dummy — it is not unfinished, it is closed.

**Rational filter** is a rule, not a device and not data filtering: a negative
session contribution recorded against a participant who makes mutually
exclusive or purely chaotic choices within one goal and one time limit. It is
the only mechanism that lowers a rating. The name is fixed in the event
`RationalFilterApplied`, in `filterTotal`, in the test
`test_VWU_RationalFilterIsCounted`, in `README.md` and in `WHITEPAPER.md` —
renaming it means renaming all of them, and after deployment the event name
cannot be changed at all.

Other terms that are fixed and not to be paraphrased in code or docs:
*secret citizen — transparent decision*; *AI acts as notary, not judge*;
*the mirror reflects, the notary bears witness, the matrix measures*.

---

## 5. What is protected

The VWU formula and everything that enters it are held in the BeTrueCore master
document, timestamped with OpenTimestamps (SHA-256), available under NDA.

Public: the composition — Activity 40% + Utility 60% — and the non-burnable
base. The contract receives a computed signed contribution and bounds it; it
does not see what that contribution was computed from, and the inputs are
deliberately kept out of call arguments, which are public.

Do not reconstruct, approximate or illustrate the protected part in code,
comments, tests or documentation, and do not add a worked example that would
let it be inferred.

---

## 6. Numbers that must agree in several places

The 736-point map is 23 Asilomar principles × 32 TDSH parameters.

| Band | Agent | Cells |
|---|---|---|
| T01–T08 | Analyst | 184 |
| T09–T16 | Strategist | 184 |
| T17–T32 | Sentinel | 368 |

A canonical cell of an agent lies inside that agent's own band. The nine cells
used by the test fixture are `A06×T02`, `A12×T04`, `A10×T08` (Analyst),
`A17×T16`, `A16×T14`, `A14×T09` (Strategist), `A18×T29`, `A19×T26`, `A11×T30`
(Sentinel), and all nine are CRITICAL in the map.

Priorities and weights: CRITICAL 3 (169 cells), HIGH 2 (515), MEDIUM 1 (47),
SUPERPOSITION 0 (5).

Verdict thresholds live in `EthicalMatrix.computeVerdict` and nowhere else:
below 40 RED, 40–69 YELLOW, 70 and above GREEN. When no cell was measurable the
result is UNDETERMINED — reported by `HarmonyAgent`, never defaulted to GREEN. A
CRITICAL cell whose own score falls in the RED band forces that side's verdict
to RED whatever the weighted mean says; the mean is still reported.

**One number that is held twice today.** The six status thresholds are declared
in `VWUEngine.sol` and again in `BeTrueCoreCore.sol`, each with its own
`_computeStatus`, and nothing compares the two. Until one file reads the other,
a threshold changes in both or in neither.

Rule for all of the above: a number that appears in the code, in the test suite
and in a document changes in all three at once, in the same commit. Two places
holding one threshold is how they drift apart.

---

## 7. What is deliberately open

Three gaps are recorded in this repository as open. They are not oversights,
and the records of them are not untidiness to be cleaned up.

1. **Set equality is not proved.** The Merkle tree is built off-chain and only
   its root reaches the contract. No published artefact shows a new root to be
   the old one with exactly the announced commitments inserted. Marked
   `not established` in the requirements table of `docs/AUTHORITY_CHAIN.md`.

2. **The verdict recomputation is not on the session path.**
   `HarmonyAgent` can recompute a verdict from the submitted cells, but
   `finalizeSession` in `BeTrueCoreCore.sol` stores the verdicts it receives and
   compares them with nothing. The function exists; the guarantee does not.

3. **`register` verifies nothing on chain.** It is external and unguarded, the
   proof argument is accepted and never read, and the number of calls is bounded
   by nothing. Resistance to an extra entry rests on the identifier checked at
   the e-government gateway, in the client — an organisational guarantee, and it
   is named as one wherever it is claimed.

**How not to close them.** The failure mode here is editing the text rather than
the code: deleting `not established`, or writing that the verdict is recomputed
on chain because the function exists. The gap survives and the warning does not,
and the next reader no longer knows where to look. Close these in code, or leave
the wording as it stands.

---

## 8. Where things are written down

| Question | File |
|---|---|
| What the protocol claims, and what it does not | `WHITEPAPER.md` |
| What a role can reach; the requirements table | `docs/AUTHORITY_CHAIN.md` |
| L0–L5 data flow, the evidential boundary | `docs/MAPPING_MODEL.md` |
| The nine agents, read-only enforcement | `docs/L5_MANAGED_AGENTS.md` |
| Anti-collusion integration | `docs/MACI_ENGINEER_PACKAGE.md` |
| Compiling and deploying the circuits | `circuits/COMPILE.md` |

---

*THE MIRROR REFLECTS • THE NOTARY BEARS WITNESS • THE MATRIX MEASURES*
