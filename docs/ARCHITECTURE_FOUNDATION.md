# Architectural Foundation of BeTrueCore

*The white paper for all integration technical documents and technologies*

---

## Where This Came From

BeTrueCore did not grow from a technical specification — it grew from a question. The question that the Odyssey asks: how does a person preserve genuine will when everything around them pressures, tempts, and distorts?

Dede Qorqud gave the second question: who bears witness? Not judges, not governs — only records the moment of collective truth and passes it forward.

*"BeTrueCore is the digital Dede Qorqud: a witness to collective wisdom, who does not judge — but measures. The Odyssey is the ecosystem that leads toward the goal: not directly, but through trials, through return to oneself."*

Read the measuring in that sentence as the system's, not the witness's: the mirror reflects, the notary bears witness, and the matrix measures. What the observing layer produces is testimony, and the measure is the map applied to the result by a rule the chain recomputes (L5 below).

Two epics. Two threads. One architecture.

The choice of these two epics is not accidental. The Odyssey belongs to the Greek — Western — tradition. Dede Qorqud belongs to the Turkic — tradition. This East-West pairing is itself an architectural statement: the system claims universality, but its roots are not exclusively Western. Infrastructure for sovereign collective intelligence must be legible across civilisational traditions, not derived from one alone.

---

## Six Layers — Six Patterns

### L0 — Identity

*Dede Qorqud: the young man's deed as the foundation of naming.*

State-registered identity is the only signature that cannot be delegated. The NIN-code never leaves the device — only its ZK-transformed commitment does. Existence itself is the signature.

The identity check itself is performed by the state before entry and is taken as a premise: the NIN is a precondition for proof of personhood, not a substitute for it. This is why the root was chosen here rather than in a test distinguishing a human from a machine — forging a register record is not the same kind of task as passing a test, and it does not get cheaper as machines improve. The cost of the choice is named beside it: those without an identifier are excluded, and the gateway sees that a given citizen passed a check through a given application.

**Technology:** MPC + NIN-code (ZK-transformed) + Web3Auth — state ID sovereignty, key fragmentation, elimination of single points of failure.

---

### L1 — Proofs

*The Odyssey: the mast as conscious limitation of external influence.*

Odysseus filled his crew's ears with wax and ordered himself tied to the mast — not because he feared, but because he knew: external pressure governs the mind. A ZK-proof does the same thing mathematically.

**Technology:** zk-SNARKs + anti-collusion protocol (Circom/Groth16) — anonymity, anti-collusion, ZK-proof generation. The mathematical shield.

---

### L2 — Execution

*Dede Qorqud: keeper of the naming protocol.*

Raw data is translated into objective immutable identifiers. Dede Qorqud did not invent names — he read the deed and named what already was.

**Technology:** Optimism L2 — fast, low-cost execution. The performance layer.

---

### L3 — Lock

*The Odyssey: the patience of Penelope.*

Penelope unraveled her shroud at night — holding the decision until the legitimate moment arrived. Time-lock does the same thing cryptographically: information symmetry until the moment of revelation.

**Technology:** Lit Protocol — time-locked voting, information symmetry. The transparency layer.

---

### L4 — Archive

*Dede Qorqud: the sound of the Gopuz as a system reset trigger.*

In the Dede Qorqud epic, the Gopuz is played at moments of collective crisis — when the community must remake a decision from a verified point, not from fiction or distortion. The Gopuz does not erase the past: it marks the moment of return to authentic order, so that what follows is built on what truly was.

Celestia DA is the digital Gopuz of BeTrueCore. It does not allow the past to be rewritten — every vote, every proof, every divergence is stored immutably. But it enables a new count from any verified point. The archive is not a prison of history; it is the guarantee that the next decision stands on honest ground.

**Technology:** Celestia DA + Solidity — immutable audit infrastructure. The memory layer.

---

### L5 — AI Agents

*The Odyssey: Ithaca — return to true nature.*

Ithaca is not a reward — it is the point of return to oneself. L5 makes no decisions. Nine agents (3×3: Analyst, Strategist, Sentinel) observe and record, and what they report is testimony rather than measurement. The ethical priority map 23×32 = 736 rules is the grammar in which a collective outcome is read: it is applied to the result of a vote and to nothing else — not to the text of a prompt, not to a participant's choice, not to the conduct of the agents. One agent of the nine, the Harmony Agent, applies it to each side of a dilemma separately and submits the cells it found touched together with its own conclusion; the chain recomputes the verdict from those cells by the map's own rule and archives both, so that any divergence stays visible. The measuring is done by the map and by the chain that recomputes against it.

**Technology:** Python + FastAPI, strict read-only mode.

**Architectural constraint:** A01 (Research Goal) is a frozen constant of the protocol — not a variable accessible to L5 agents at runtime.

---

## Operator Decentralisation

The protocol follows a progressive decentralisation of operator control across three phases:

**Phase 1 — Human + Mathematics:** sessions are opened and finalisation coordinated by hand, with mathematics ensuring correctness. The coordinator and the operator are the community itself; this phase describes who performs the work, not a party standing above the participants.

**Phase 2 — Mathematics:** Lit Protocol MPC assumes the coordinator role. The work leaves human hands and remains only at the infrastructure level.

**Phase 3 — Community:** The community drives the full 7-step cycle. VWU determines signal weight. The Harmony Agent observes and proposes; the chain recomputes. No emergency human role is retained at the contract level — retaining one would keep in place exactly what these three phases exist to dissolve.

**What this costs while it is still in motion.** Until the last phase, roles are held by addresses: the coordinator, the address that writes the Merkle root, the address registered as the Harmony Agent. Each is transferred in two steps — the holder nominates, the nominee accepts — and both steps emit events, so a change of hands is archived rather than silent. That such a role belongs to the community cannot be proved while an address holds it: it is disclosed, not proved, and a reader is relied upon to look. No statute closes this, and none is offered as closing it — a community has no legal personality and needs none, and the statutes of the association that operates the application are the association's, not the community's. The role becomes proved by disappearing. That is what Phase 3 means, and it is the measure by which this progression is finished or unfinished (`docs/AUTHORITY_CHAIN.md`, §14).

This is "AI as notary, not judge" in motion: in Phase 1 the notary is human; in Phase 3 the notary is the protocol itself. L5 is not the notary at the end of this road — it is the witness whose testimony the protocol checks.

---

## Two Taxonomies, One System

L0–L5 and the four TDSH modules are not competing descriptions — they are different axes of the same architecture.

**L0–L5** describes the technical stack: the six layers through which a collective decision is formed, protected, executed, locked, archived, and observed. This is the infrastructure.

**TDSH Modules 1–4** (Verification, Ethics, Scaling, Security) describe the measurement system: the four dimensions along which the quality of collective judgment is evaluated in real time. This is the instrument.

Both operate simultaneously. A developer building on BeTrueCore navigates L0–L5. A researcher studying collective judgment reads what the Panorama publishes — the roster total, the three rows of a session outcome, and a verdict on each side of a dilemma — and nothing beyond it: the TDSH modules are the instrument by which a result is read inside the protocol, not a channel out of it. The same system; two lenses.

---

## The Constitutional Formula

*The mirror reflects. The notary bears witness. The matrix measures.*

Three actions. Not a single decision. The ability to live with open questions is not a weakness of the architecture. It is its principle.

---

## The Principle Is Immutable

All technologies may change. The stack is updated. Contracts are rewritten. What does not change is the design intent, fixed by hash in the master document: where intent and code diverge, the code and the documents are what move, and the master document stays as it was written. This file is one of those documents — it is kept in step with the code and carries corrections as they are found. If at any point in the process of building a question arises — "are we on the right path?" — the answer is here, and if the answer here has gone out of step with the master document, the master document decides.

---

*BeTrueCore Modular System — Web3 Intuitive Symmetry Methodology (Web3-ISM) v1.2*

**Analogy methodology:** [AAA Document](../AAA_document_EN.md)
*ORCID: 0009-0004-4841-594X*
*Timestamped via OpenTimestamps (SHA-256)*

**Preprint series:** Zenodo — [10.5281/zenodo.21466246](https://doi.org/10.5281/zenodo.21466246) (Preprint 10 — Four Principles as the Foundation of TDSH)
**Repository:** [github.com/Dede-Qorqud/BeTrueCore](https://github.com/Dede-Qorqud/BeTrueCore)