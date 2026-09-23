# Authority Chain: BeTrueCore as the Organisational Approval Layer

*BeTrueCore Modular System — Web3-ISM v1.2*
*ORCID: 0009-0004-4841-594X*
*Timestamped via OpenTimestamps (SHA-256)*

---

## 1. The Problem: Agentic AI Needs Verifiable Authority

As AI agents move from generating content to conducting transactions, a
structural gap emerges in existing trust infrastructure.

Hagen Saxowski (Digital Identity & Trust Infrastructure) formulated this
precisely in September 2026:

> *"Agentic AI does not primarily have an identity problem. It has an
> end-to-end trust problem."*

The full chain an economically meaningful agent requires:

```
Identity → Representation → Authorisation → Runtime Enforcement → Accountability
```

Existing infrastructure handles identity well. The NIST concept paper on
Software and AI Agent Identity and Authorisation (February 2026) and the European
eIDAS 2.0 / EUDI Wallet framework address the first link reliably.

The critical gap sits in the middle: **how do we translate legal authority into
machine-verifiable and machine-enforceable authority?**

This document describes where BeTrueCore sits in that chain — and why it
addresses a case that existing architectures assume but do not solve.

---

## 2. The Reference Architecture: M-Trust (Spherity, 2026)

The most complete existing answer to the agentic authority problem is the
M-Trust reference architecture published by Dr. Carsten Stöcker (Spherity GmbH)
on 16 September 2026:

> *"Beyond Single-Enterprise ZTA: Multi-Trust Architectures for Authorised
> Agentic Actors"*
> spherity.github.io/spherity-research/beyond-zero-trust-m-trust-authorised-agentic-actors.html

M-Trust defines an eight-layer authority chain for B2B agentic transactions:

| Layer | Description |
|---|---|
| 1 | Authoritative source (legal register, credential issuer) |
| 2 | Legal person (company, organisation) |
| 3 | Authorised representative (human with signing authority) |
| 4 | Agent identity (workload identity, digital twin) |
| 5 | Task-bounded mandate (scope, limits, duration) |
| 6 | Policy decision + enforcement point |
| 7 | Controlled action (the transaction) |
| 8 | Signed action receipt (evidence for accountability) |

This architecture is well-designed for the B2B case where the principal is a
legal person (a company). Layer 3 — authorised representative — provides the
bridge between legal authority and machine-executable mandate.

---

## 3. The Missing Layer: Organisational Approval Without Proof

Within the M-Trust chain, one link has no machine-verifiable counterpart:

**Layer 2 → Layer 3 transition: organisational approval.**

For an agent to act on behalf of a company, the company must have internally
approved the delegation. In practice, this approval exists as:

- A board resolution (PDF)
- A meeting protocol (Word document)
- An internal policy (email thread)

None of these is machine-verifiable at the moment of transaction. The verifying
party must trust the claim that approval was granted — not the proof that it was.

Saxowski identified this as the hardest gap:

> *"How do we translate legal authority into machine-verifiable and
> machine-enforceable authority? That authority must be verifiable across
> organisational and jurisdictional boundaries — and enforceable at the moment
> the transaction happens."*

The concept from payment systems — **dynamic linking** (PSD2: confirmation
bound to a specific amount and counterparty) — has no equivalent for
organisational decisions.

BeTrueCore provides that equivalent.

---

## 4. The Collective Principal Problem

M-Trust is designed for a principal that already holds legal authority:
a company, a state, a licensed institution.

But a large and growing class of collective actors falls outside this model:

- Community organisations without legal personhood
- Cooperatives governed by member vote
- DAOs (decentralised autonomous organisations)
- Civic associations making binding internal decisions
- Participatory bodies (residents' councils, neighbourhood committees)

For these actors, **there is no Layer 2 in the M-Trust sense**. The principal
is not a legal person — it is a collective whose authority derives from
a decision process, not from registration.

This creates a structural gap:

```
Existing infrastructure:  Legal Person → Representative → Agent → Transaction
                                  ↑
                           (requires legal status)

Collective principal:      Decision Process → ??? → Agent → Transaction
                                  ↑
                           (no machine-verifiable equivalent exists)
```

BeTrueCore was designed to close this gap from the ground up.

---

## 5. BeTrueCore as the Organisational Approval Layer

BeTrueCore L1 produces a **ZK-proof of collective decision** (ZK-Beschluss):
a cryptographic record that proves a decision was reached by a verified quorum
of participants — without revealing who voted how.

This proof has three properties the PDF-based approval lacks:

**1. Verifiability at the moment of transaction.**
Any counterparty can verify the ZK-proof on-chain without contacting
BeTrueCore infrastructure. Verification is stateless, instant, and
trustless.

**2. Scope binding.**
The proof encodes the decision's parameters: what was decided, under what
quorum threshold, within what time window. An agent mandate derived from this
proof inherits these scope constraints — equivalent to PSD2 dynamic linking,
applied to a collective decision rather than a payment.

**3. Privacy preservation.**
The proof attests that the collective decided — without exposing the
identity of any participant or the distribution of individual votes.
The decision is transparent. The citizens are secret.

This directly maps to the M-Trust chain:

| M-Trust Layer | BeTrueCore Component |
|---|---|
| Authoritative source | ZK-nullifier registry (L0) — one citizen, one identity |
| Collective principal | Community of verified participants (L0+L1) |
| **Organisational approval** | **ZK-Beschluss: L1 proof of quorum decision ← fills the gap** |
| Task-bounded mandate | Decision parameters encoded in the ZK-proof |
| Policy enforcement | EthicalMatrix.sol + HarmonyAgent.sol (L2) |
| Accountability | Celestia DA immutable archive (L4) |
| Observation layer | L5 AI agents — read-only witnesses (L5) |

---

## 6. What BeTrueCore Does Not Do

Precision matters. BeTrueCore is not a replacement for M-Trust, eIDAS, or
EUDI Wallet. It does not provide:

- Agent authentication to APIs (that is IAM / EUDI territory)
- Runtime policy enforcement at transaction boundaries (M-Trust Layer 6)
- Signed action receipts for completed transactions (M-Trust Layer 8)
- Legal personhood for collective actors
- Cross-border identity recognition under eIDAS

BeTrueCore provides **one layer**: the machine-verifiable record of what a
collective decided and the constraints under which it delegated authority.
Everything downstream (agent identity, policy enforcement, action receipts)
is handled by existing infrastructure.

**The relationship is additive, not competitive:**

```
BeTrueCore L1 ZK-Beschluss
        │
        └─► feeds into M-Trust Layer 3 (organisational approval)
                │
                └─► rest of M-Trust chain operates normally
```

---

## 7. Integration Map

```
eIDAS / EUDI Wallet               BeTrueCore                M-Trust Chain
──────────────────────            ──────────────            ─────────────────
                                  L0 — Identity             Layer 1: Auth. source
Individual identity ─────────────► NIN + ZK commit          Layer 2: Legal person
                                       │
                                  L1 — Proofs               Layer 3: Auth. representative
                                  ZK-Beschluss ────────────► (collective approval)
                                       │
                                  L2 — Execution            Layer 4–5: Agent + mandate
                                  VWU + scope params ──────► (decision constraints)
                                       │
                                  L3 — Lock                 Layer 6: Policy enforcement
                                  Lit Protocol ────────────► (time symmetry)
                                       │
                                  L4 — Archive              Layer 8: Action receipt
                                  Celestia DA ─────────────► (immutable audit)
                                       │
                                  L5 — AI Agents
                                  Read-only witnesses
                                  (no authority, no action)
```

---

## 8. The AI Agent's Role: Notary, Not Judge

Within this authority chain, BeTrueCore's L5 AI agents occupy a specific and
strictly bounded position.

They do not:
- Grant or verify authority (that is L1's function)
- Execute or enforce decisions (that is L2's function)
- Store or release locked results (that is L3's function)

They do:
- Observe the quality of the decision process in real time
- Detect anomalies (Sybil patterns, coordinated manipulation, paradoxical
  behaviour sequences)
- Report in a structured traffic-light format to the human review layer
- Write nothing — ever

The constitutional principle is unchanged across all contexts:

> *"AI is the notary. The human is the author.
> The notary cannot become a judge: it has no technical mechanism to forge
> the author's verdict."*

In the M-Trust framework, the L5 layer maps closest to Layer 8 (accountability)
— but as an observer of the process that produces the action receipt, not as
the issuer of that receipt. The ZK-cryptography issues the receipt. L5 watches
whether the process was clean.

---

## 9. Scope and Current Status

**What exists today (Phase 1):**

- ZK identity circuit: `circuits/NINCommitment.circom` + `circuits/NINIdentityProof.circom` — v0.1
- Anti-collusion contract: `src/IBeTrueCoreAntiCollusion.sol` + `src/Poll.sol` — v0.1
- VWU engine: `src/VWUEngine.sol` — v0.4
- Ethical matrix: `src/EthicalMatrix.sol`
- Harmony orchestrator: `src/HarmonyAgent.sol`
- L5 implementation specification: `docs/L5_MANAGED_AGENTS.md`

**What the ZK-Beschluss provides to an M-Trust-compatible system:**

A machine-readable, on-chain verifiable record that:
- A quorum of verified individuals participated (L0)
- A specific decision was reached under defined parameters (L1)
- No individual vote is traceable to any identity (ZK privacy)
- The record cannot be altered retroactively (L4 — Celestia DA)

**What is not yet implemented:**

The formal interface between BeTrueCore's L1 output and an M-Trust-compatible
policy engine (Layer 6). This is the Phase 2 integration point — the boundary
at which the ZK-Beschluss is consumed by an external authority chain.

---

## 10. Positioning Statement

BeTrueCore answers a question that Saxowski and Stöcker have put on the table
precisely, but for a case neither paper addresses:

> *What is the root of authority when the principal is a collective —
> a community, cooperative, or DAO — rather than a legal person?*

The answer is not a new identity system. It is a verifiable decision record:
a ZK-proof that the collective reached this decision, under these conditions,
within these constraints — without exposing who contributed.

This is not the full authority chain. It is the missing first link.

---

## References

- Saxowski, H. (2026). *Agentic AI has an identity problem. But the harder
  problem is authority.* LinkedIn, September 2026.
- Saxowski, H. (2026). *Agentic AI does not primarily have an identity problem.
  It has an end-to-end trust problem.* LinkedIn, September 2026.
- Stöcker, C. et al. (2026). *Beyond Single-Enterprise ZTA: Multi-Trust
  Architectures for Authorised Agentic Actors.* Spherity GmbH.
  spherity.github.io/spherity-research/beyond-zero-trust-m-trust-authorised-agentic-actors.html
- NIST (2026). *Concept Paper: Software and AI Agent Identity and Authorization.*
- Guliyev, F. (Safarnur) (2026). *From Coordination Collapse to Collective
  Wisdom: Extending the VWU Model.* Zenodo. DOI: 10.5281/zenodo.22179301
- Guliyev, F. (Safarnur) (2026). *Threshold and Witness: From a Model of
  Collective Behaviour to an Architecture of Collective Judgment.* Zenodo.
  DOI: 10.5281/zenodo.22537058
- [BeTrueCore Architecture Foundation](./ARCHITECTURE_FOUNDATION.md)
- [L5 AI Agent Implementation](./L5_MANAGED_AGENTS.md)

---

*BeTrueCore Modular System — Web3 Intuitive Symmetry Methodology (Web3-ISM) v1.2*
*Repository: [github.com/Dede-Qorqud/BeTrueCore](https://github.com/Dede-Qorqud/BeTrueCore)*
*Timestamped via OpenTimestamps (SHA-256)*
