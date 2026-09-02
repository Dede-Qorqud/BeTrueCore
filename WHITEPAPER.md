# BeTrueCore Whitepaper

**BeTrueCore Modular System — Web3 Intuitive Symmetry Methodology (Web3-ISM) v1.2**

Cryptographic Infrastructure for Sovereign Collective Decision-Making.

**Author:** Farman Guliyev (Safarnur)  
**ORCID:** [0009-0004-4841-594X](https://orcid.org/0009-0004-4841-594X)  
**Version:** 1.1 — July 2026  
**Status:** Working Draft — TRL 2→3  
**License:** CC BY-NC 4.0

---

## Abstract

*The mirror reflects. The notary bears witness. The matrix measures.*

BeTrueCore is a cryptographic infrastructure for sovereign collective decision-making. The protocol addresses a structural problem that precedes any governance framework: the act of expressing a preference is never truly private, and what is observed is not always authentic. BeTrueCore inverts the dominant paradigm — from *transparent citizen, secret vote* to *secret citizen, transparent decision* — through a six-layer architecture integrating ZK-SNARKs, MACI, state-identifier sovereignty, and a mathematically weighted participation system (Vote Weight Unit). AI agents operate exclusively in read-only mode: they observe, record, and measure. The decision remains with the human.

---

## 1. The Problem

*Wabi-sabi — imperfection as creative resource.*

Three structural failures define the existing landscape of collective decision-making.

**Preference falsification.** As Timur Kuran demonstrated, individuals systematically misrepresent their true preferences under conditions of social observation. Any system that infers collective will from observed behaviour learns performed preferences — not authentic ones. The Panopticon, described by Foucault and extended into the digital domain by Zuboff, operates at full force on every existing platform for collective decision-making.

**Aggregation failure.** Simple majority voting destroys minority signals. Token-weighted governance reproduces financial hierarchy in cryptographic form. Neither mechanism reflects genuine collective intelligence — only the loudest or wealthiest fraction of it.

**The Gödelian boundary.** Any sufficiently complex formal ethical system is necessarily incomplete by definition. BeTrueCore does not attempt to encode a complete ethical framework. It creates infrastructure through which people continuously and verifiably express their own values — and measures the quality of that expression over time.

---

## 2. The Inversion

*Secret citizen — transparent decision.*

Two epics. Two threads. One inversion.

Dede Qorqud did not invent names — he read the deed and named what already was. Identity is born from action, not prior to it. The deed is the signature.

Odysseus called himself "Nobody" — not out of cowardice, but strategy. By concealing his identity, he accomplished the deed. Anonymity became the condition for authentic action.

The dominant governance model is structured differently: the state, the platform, and the algorithm know who you are. Your decision is nominally private. But the environment in which you *form* that decision — the recommendations you receive, the social signals you observe, the visibility of others' choices — is not private at all. You decide under observation. The Panopticon does not disappear at the moment of choice — it is present at the moment of its formation.

BeTrueCore proposes the inversion: identity is cryptographically protected at the moment of choice. The decision, formed in genuine isolation, is open and verifiable. The signal is clean — because the conditions of its formation were protected.

This is not individual heroism. It is a collective and iterative process. Dede Qorqud bears witness — he does not judge. Odysseus returns to himself through anonymity — not through coercion.

---

## 3. The Theory of Clean Signal

*Kintsugi — errors as golden seams of evolution.*

Collective intuition exists in every group of people. The question is not whether it exists — but whether it can be measured without distortion.

Poincaré described four stages of mathematical creativity: preparation, incubation, illumination, verification. BeTrueCore reproduces this cycle collectively — each session is an iteration of Bayesian updating. The previous experience of a participant influences the weight of their judgment. Accumulated collective knowledge is refined with each cycle.

But the signal does not purify itself. It is contaminated at the moment of observation — by social pressure, algorithmic amplification, fear of judgment. Stochastic resonance describes a paradoxical effect: moderate noise helps a weak signal emerge. BeTrueCore uses this principle architecturally — cryptographic isolation does not eliminate human uncertainty, it protects it from external distortion.

The result — immune islands of clean signal. Small communities, protected from algorithmic noise and social pressure, form collective judgment iteratively. Each cycle of genuine participation updates collective understanding. Each protected judgment contributes to a signal that accumulates over time.

An error in this system is not a failure. It is a golden seam. Kintsugi archives the deviation as part of evolution — it does not erase it.

---

## 4. Architecture

*Existence itself is the signature.*

BeTrueCore is structured across six layers. Each layer is an independent component communicating with others through defined interfaces with cryptographic boundary guarantees.

```
L0  Identity    State ID (NIN code) + ZK + MPC 2-of-3
     ↓          State ID sovereignty — original NIN code never leaves the device

L1  Proofs      ZK-SNARKs + MACI v1.2
     ↓          Anonymity, anti-collusion, receipt-freeness

L2  Execution   Optimism L2
     ↓          VWU calculation, smart contract execution

L3  Lock        Lit Protocol
     ↓          Time-locked voting, information symmetry until reveal

L4  Archive     Celestia DA
     ↓          Immutable public audit log

L5  AI Agents   Analyst × 3 + Strategist × 3 + Sentinel × 3
                READ-ONLY — no write access to any data structure
```

**L0 — Identity.** ZK commitment is generated on-device from state identifier (NIN — National Identification Number). For example: Birth number (Rodné číslo) — a unique identifier for persons in the Czech Republic. Original NIN never leaves the device. Private keys are fragmented using Shamir Secret Sharing (threshold 2-of-3) via MPC — the key is never reconstructed in a single location — the single point of failure is eliminated.

**L1 — Proofs.** Zero-knowledge proofs separate the act of decision-making from its social observation. MACI v1.2 provides key-rotation: a participant may change their decision any number of times before session close — only the final decision counts. Coercion and purchase of decisions are mathematically meaningless: the seller retains the ability to silently override the choice.

**L2 — Execution.** Smart contracts manage the session lifecycle, VWU calculation, and result finalization. Optimism L2 provides fast, low-cost execution without compromising Ethereum-level security.

**L3 — Lock.** Lit Protocol enforces information symmetry: no participant, administrator, or AI agent can see intermediate results during a session. The time-lock releases simultaneously for all parties at session close.

**L4 — Archive.** Celestia DA stores the immutable public audit log. Any independent observer can verify the integrity of any session without trusting BeTrueCore infrastructure.

**L5 — AI Agents.** Nine agents of three types — Analyst, Strategist, Sentinel — three agents of each type (3×3) — operate in strict read-only mode. This is not a policy — it is an architectural property encoded in smart contracts. A compromised agent gains observation rights, not action rights. The notary cannot be compelled to commit forgery.

---

## 5. Core Mechanisms

*My identity is my fortress.*

Four mechanisms form the operational core of BeTrueCore.

### 5.1 MACI + ZK — Protection of the Moment of Choice

MACI v1.2 implements the impossibility of proving a decision to a third party. A participant cannot prove their choice to anyone — because all intermediate decisions are cryptographically equiprobable. Only the final decision counts.

```
Session open
     ↓
Participant submits encrypted decision (MACI key)
     ↓
Participant may rotate key + submit new decision (any number of times)
     ↓
TIME LOCK — session closes
     ↓
Only FINAL decision counts (all previous keys invalidated)
     ↓
MACI coordinator publishes result + ZK correctness proof
     ↓
Coordinator cannot falsify — fraudulent proof rejected by verifiers
```

### 5.2 VWU — Mathematical Weight of Participation

Vote Weight Unit is a dynamic participation weight assigned to each participant. Non-transferable, non-marketable, invisible to other participants. Accumulates through quality of judgment — not capital or status.

Public interface (inputs → output):

| Input | Description |
|---|---|
| `activity_score` | Completeness of session participation (0–100) |
| `aligned_majority` | Whether final decision aligned with weighted majority |
| **Output** | **Description** |
| `vwu_delta` | Increment to participant VWU balance |

The VWU formula is protected in the master document (OpenTimestamps SHA-256). Inputs and output are publicly disclosed — sufficient for integration. Full specification available to verified partners.

Six status levels: SOLO → SELFLY → UNIVERSAL → HONORIS → LUMINARE → VERITAS_ZK.

### 5.3 Ethical Priority Map — 736 Points

23 Asilomar Principles × 32 TDSH parameters = 736 intersections. Each intersection is a formal rule governing agent behaviour.

| Priority | Weight | Cells | % of Matrix |
|---|---|---|---|
| CRITICAL | 3 | 169 | 23.0% |
| HIGH | 2 | 515 | 70.0% |
| MEDIUM | 1 | 47 | 6.4% |
| SUPERPOSITION | 0 | 5 | 0.7% |

The 32 TDSH parameters are structured as 4 modules × 8 parameters, grounded in four physical principles by structural analogy: symmetry (Module 1), thermodynamics (Module 2), electromagnetism (Module 3), gravitation (Module 4).

### 5.4 Anonymous Research Layer

BeTrueCore's spatial interface architecture — three levels (Local, National, Research) — includes a dedicated Research screen, structurally independent from the standard user session flow and governed by the same constitutional principles of the system.

The Research submits a binary dilemma directly — bypassing the competitive TOP-3 mechanism. Participants see the question on a dedicated screen without knowing who commissioned it.

What the Research receives: the Panorama — the same cryptographically sealed result every participant receives. Nothing more. No intermediate results, no participant identities, no influence over the session.

This is not advertising. It is clean collective signal as a service.

### 5.5 ZK Security Boundary — Quantum Horizon

BeTrueCore's L1 architecture uses zero-knowledge proofs based on Groth16/BN254. This raises two fundamentally distinct security questions that must not be conflated.

**Current protection: opacity as a formal property.** The zero-knowledge property guarantees that no observer — human, AI analyser, or quantum system — can extract information about who voted and what they chose from a published proof. This follows not from computational hardness but from the existence of a simulator capable of generating indistinguishable proofs without knowledge of the witness. Past votes are permanently protected, regardless of future computational capabilities.

**Quantum horizon: a threat to soundness, not to opacity.** Shor's algorithm on a Cryptographically Relevant Quantum Computer (CRQC) could solve the Elliptic Curve Discrete Logarithm Problem (ECDLP) underlying BN254, potentially enabling fabrication of new proofs — a soundness violation affecting future votes only. This threat is credible on a 2030–2035 horizon per NIST and G7 assessments. The migration path is defined: replacement of the L1 proof scheme from Groth16 to zk-STARK (based on collision-resistant hash functions; natively post-quantum). Levels L2–L5 remain unaffected — BeTrueCore's modular architecture was designed precisely to accommodate this substitution.

---

## 6. AI as Notary

*AI as notary, not judge.*

The observer principle is not a declaration of intent. It is an architectural property encoded in smart contracts.

| Agent | Reads | Decides | Function |
|---|---|---|---|
| Analyst × 3 | L0 ZK commitments, L1 proofs | NEVER | Signal verification |
| Strategist × 3 | L2 results, L4 audit | NEVER | Pattern analysis, Sybil detection |
| Sentinel × 3 | L0–L4 all layers | NEVER | Security monitoring |

A compromised Analyst sees ZK commitments — but cannot write to the VWU. A captured Strategist identifies coordination patterns — but cannot alter consensus outcomes. A compromised Sentinel stops flagging violations — but the anomaly becomes visible in the Celestia DA log.

In all scenarios the attacker gains visibility — not power.

The observational layer sees the reflection in the mirror. It cannot alter it — not by moral intent, but by the structure of the environment.

---

## 7. The Ethical Architecture

*The mirror reflects. The notary bears witness. The matrix measures.*

736 points — not a list of rules. This is the DNA of the agents.

The Ethical Priority Map is built on the intersection of two systems: 23 Asilomar Principles — internationally recognised guidelines for safe AI — and 32 TDSH parameters — BeTrueCore's internal system of collective decision hygiene. The Cartesian product yields 736 intersections. Each is a formal rule governing agent behaviour in a specific context.

VWU is the measurement instrument within this architecture. It does not evaluate the participant's identity — it measures the quality of judgment over time. The matrix sets the ethical boundaries of agents. VWU records the quality of the human signal. Together they form a closed loop: ethics defines the framework of observation, observation measures the signal, the signal returns to the system as accumulated collective knowledge.

Scale invariance is the key property of the architecture. 736 rules operate identically at the level of a small group and at the global level. The size of the community changes the volume of data — not the structure of measurement.

---

## 8. Implementation Status

Architecture, mathematical model, and technical specification are complete and timestamp-protected.

### 8.1 Research and Specification

- 11 academic preprints published on Zenodo (ORCID: 0009-0004-4841-594X)
- Master document: 19,012 words, protected by OpenTimestamps SHA-256 timestamp
- 736-point Ethical Priority Map formalised
- Evidential layer boundary defined (MAPPING_MODEL v0)
- ERC-8281 integration points identified at L1 and L3

### 8.2 Technical Implementation

Developer Package v0.1 includes five smart contracts, the IBeTrueCore interface, and a Foundry test suite.

Damon Zwicker (ERC-8281 – Observation Commitment Protocol) reviewed the proposed integration of ERC-8281 into BeTrueCore and helped clarify the architectural boundary between BeTrueCore's private transition logic and ERC-8281's independently verifiable commitment layer. The discussion focused on the VoteProof observation envelope at L1 and the two-point commitment structure surrounding the Lit Protocol time-lock at L3. ERC-8281 provides an independently verifiable commitment layer for those observations and transitions without requiring access to BeTrueCore's private VWU inputs, internal protocol semantics, or governance logic.

Pavlo Tvardovskyi — author of ReceiptOS, a portable recomputable evidence substrate (DOI [10.5281/zenodo.21402444](https://doi.org/10.5281/zenodo.21402444)) — defined the evidential layer boundary through joint work on BeTrueCore Evidential Layer × ReceiptOS Mapping v0. ReceiptOS supplies recomputable proof references and nothing else — it does not produce, consume, or endorse VWU scoring.

*Note: This whitepaper is published under CC BY-NC 4.0. ReceiptOS remains independently licensed under CC BY 4.0.*

### 8.3 Prototype — BTC-Test

Prior to full cryptographic implementation, the protocol was validated on a live group. The BTC-Test pilot was conducted with a group of 21 participants — former classmates. Participants were presented with 13 dilemmas — covering topics of health, family, justice, security, heritage, technology, and faith — and asked to select the 3 most significant for the group. The three selected dilemmas became the session agenda.

The BTC-Lite protocol was used — a trust-based variant without blockchain. Participants received the dilemmas in a WhatsApp group and submitted their choices by SMS to the organiser's personal phone over the course of one day. Each participant received an anonymous number in return. The three dilemmas with the highest vote count became the agenda. Answers A/B for each dilemma were collected in the same format — at a time convenient for each participant. Results were published simultaneously for all at 20:00. VWU mechanics and the traffic-light verdict system were applied in full.

12 participants responded. Group activity: 57%. Average group VWU: 4.51.

**Three dilemmas:**

| Dilemma | Simple Majority | Weighted Result | Verdict |
|---|---|---|---|
| Who should make a risky surgical decision — doctor or patient? | B — Patient (85.7%) | B — 92.1% | ✱GREEN |
| What is more important to leave children — property or values? | B — Values (100%) | B — 100% | ✱GREEN |
| Should a grown child's phone be monitored or trusted? | A — Monitor (75%) | A — 74.1% | ✱GREEN |

All three dilemmas returned a GREEN verdict — judgment is stable. Dilemma with greatest unity: Values. Dilemma with greatest discrepancy: Monitor.

The pilot confirmed: the mechanics work on a live group prior to technical implementation. The weighted result differs from simple majority — and this difference is perceived by the group as meaningful.

### 8.4 Current Stage and Roadmap

Current stage: TRL 2 → TRL 3

| Phase | Duration | Milestone |
|---|---|---|
| Phase 1 — Core | 1–2 months | MACI testnet + ZK identity circuit + VWU contract |
| Phase 2 — Integration | 2–3 months | Lit Protocol + Celestia DA + Optimism L2 deployment |
| Phase 3 — Pilot | 1–2 months | Closed pilot 50–100 users + full audit |

---

## 9. How to Contribute

BeTrueCore is at TRL 2 → TRL 3. Architecture, mathematical model, and specification are complete. Seeking a technical partner for core implementation.

**Critical path (MVP):**

1. MACI v1.2 smart contract deployment (testnet)
2. ZK identity circuit (Circom) — state ID commitment + nullifier
3. VWU calculation contract integration

Without these three components the system does not function. Celestia and Lit Protocol — Phase 2.

**Technology stack:**

| Layer | Language / Framework |
|---|---|
| Smart contracts (L1–L2) | Solidity ^0.8.19 + Foundry |
| ZK circuits | Circom 2.0 + snarkjs |
| MPC / Identity | Web3Auth MPC Core Kit v3+ |
| Time-lock | Lit Protocol SDK v6+ |
| Data availability | Celestia node v0.12+ |
| Backend orchestration | TypeScript (Node 20 LTS) |
| AI agents | Python 3.11+ + FastAPI |

**What is open:**

- Full smart contract suite (Developer Package v0.1)
- MACI integration specification (MACI_ENGINEER_PACKAGE.md)
- Evidential layer boundary model (MAPPING_MODEL.md)
- Architectural foundation (ARCHITECTURE_FOUNDATION.md)
- 736-point Ethical Priority Map (Excel + Solidity)
- Foundry unit tests

**What is protected:**

- VWU non-linear growth factor and full formula.
- Master document (available to verified partners).

If you are a Solidity / Circom / ZK developer interested in sovereign collective intelligence — open an Issue or reach out via ethresear.ch: [Dede-Qorqud](https://ethresear.ch/u/Dede-Qorqud)

---

## 10. References

**Protocols:**

- MACI anti-collusion pattern (Circom/Groth16) — repository archived August 19, 2026
- Asilomar AI Principles — [futureoflife.org/ai-principles](https://futureoflife.org/ai-principles/)

**Philosophical and scientific sources:**

- Kuran, T. (1995). *Private Truths, Public Lies.* Harvard University Press.
- Foucault, M. (1975). *Surveiller et punir.* Gallimard.
- Zuboff, S. (2019). *The Age of Surveillance Capitalism.* PublicAffairs.
- Gödel, K. (1931). *Über formal unentscheidbare Sätze.* Monatshefte für Mathematik und Physik.
- Poincaré, H. (1908). *Science et méthode.* Flammarion.

**Repository and publications:**

- GitHub: [github.com/Dede-Qorqud/BeTrueCore](https://github.com/Dede-Qorqud/BeTrueCore)
- Paragraph: [@betruecore](https://paragraph.xyz/@betruecore)
- ethresear.ch: [Dede-Qorqud](https://ethresear.ch/u/Dede-Qorqud)

---

*THE MIRROR REFLECTS • THE NOTARY BEARS WITNESS • THE MATRIX MEASURES*
