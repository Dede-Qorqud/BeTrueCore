# BeTrueCore Whitepaper

**BeTrueCore Modular System — Web3 Intuitive Symmetry Methodology (Web3-ISM) v1.2**

Cryptographic Infrastructure for Sovereign Collective Decision-Making.

**Author:** Farman Guliyev (Safarnur)  
**ORCID:** [0009-0004-4841-594X](https://orcid.org/0009-0004-4841-594X)  
**Version:** 1.2 — October 2026   
**Status:** Working Draft — TRL 2→3  
**License:** CC BY-NC 4.0

---

## Abstract

*The mirror reflects. The notary bears witness. The matrix measures.*

BeTrueCore is a cryptographic infrastructure for sovereign collective decision-making. The protocol addresses a structural problem that precedes any governance framework: the act of expressing a preference is never truly private, and what is observed is not always authentic. BeTrueCore inverts the dominant paradigm — from *transparent citizen, secret vote* to *secret citizen, transparent decision* — through a six-layer architecture integrating ZK-SNARKs, the MACI anti-collusion pattern implemented on Circom/Groth16, state-identifier sovereignty, and a mathematically weighted participation system (Vote Weight Unit). AI agents operate exclusively in read-only mode: they observe, record, and bear witness. What they report is testimony, not measurement (5.8). The decision remains with the human.

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

L1  Proofs      ZK-SNARKs + anti-collusion protocol (Circom/Groth16)
     ↓          Choice unlinkability (scope: 5.6), receipt-freeness (scope: 5.7)

L2  Execution   Optimism L2
     ↓          VWU calculation, smart contract execution

L3  Lock        Lit Protocol
     ↓          Time-locked voting, information symmetry until reveal

L4  Archive     Celestia DA
     ↓          Immutable public audit log

L5  AI Agents   Analyst × 3 + Strategist × 3 + Sentinel × 3
                READ-ONLY — no write access to any data structure
                Reads participant-authored text; boundary in 5.8
```

| Agent | Reads | Decides | Function |
|---|---|---|---|
| Analyst × 3 | L4 archive — commitments and proof records | NEVER | Signal verification |
| Strategist × 3 | L4 archive — session results and audit log | NEVER | Ethical signal, risk signal, and the Harmony Agent's verdict proposal |
| Sentinel × 3 | L4 archive — records of all layers as archived | NEVER | Security monitoring |

Every row reads one and the same channel. No agent reaches a layer directly:
it reads what the L4 archive exposes through a read-only gateway whose schema
holds `read_session_data`, `read_proof_record` and `compute_vwu_snapshot` and
no write endpoint at all. "Records of all layers" in the last row therefore
means the records of those layers as the archive keeps them, not access to the
layers themselves. The boundary is set out in `docs/MAPPING_MODEL.md`, at the
L4 → L5 table.

**L0 — Identity.** ZK commitment is generated on-device from state identifier (NIN — National Identification Number). For example: Birth number (Rodné číslo) — a unique identifier for persons in the Czech Republic. Original NIN never leaves the device. Private keys are fragmented using Shamir Secret Sharing (threshold 2-of-3) via MPC — the key is never reconstructed in a single location — the single point of failure is eliminated.

What the protocol establishes here, stated exactly: the commitment is bound to a triple of numbers held on the device, and binding that triple to a real person happens in the client, which checks the identifier at the e-government gateway. Nothing on-chain enforces that check — the circuit accepts freely chosen inputs, and the contract receives a root without learning what the leaves under it were built from. The NIN is a precondition for proof of personhood, not a substitute for it: whether this is a person, and one person, is settled by the state before entry and taken as a premise. The cost of this choice is named rather than left out — those without an identifier are excluded, and the gateway sees that a given citizen passed a check through a given application, though not which community, dilemma, or choice followed.

**L1 — Proofs.** Zero-knowledge proofs separate the act of choosing from its social observation. The anti-collusion protocol provides key-rotation: a participant may change their choice before session close, up to a per-participant message limit — only the final choice counts. Buying a *stated* choice is therefore pointless: the seller can state one thing and silently override it afterwards. Buying the *key* is not pointless, and coercion is not defeated — the exact boundary is stated in 5.7.

**L2 — Execution.** Smart contracts manage the session lifecycle, VWU calculation, and result finalization. Optimism L2 provides fast, low-cost execution without compromising Ethereum-level security.

**L3 — Lock.** Lit Protocol enforces information symmetry: no participant and no AI agent can see intermediate results during a session, and nothing can be decrypted by anyone before the time lock expires. The time-lock releases simultaneously for all parties at session close. The coordinator named in 5.1 is a protocol role held by an address, not a party standing above the participants; what can and cannot be proved about who holds it is stated in 5.9.

**L4 — Archive.** Celestia DA stores the immutable public audit log. Any independent observer can verify the integrity of any session without trusting BeTrueCore infrastructure.

**L5 — AI Agents.** Nine agents of three types — Analyst, Strategist, Sentinel — three agents of each type (3×3) — operate in strict read-only mode. This is not a policy — it is an architectural property encoded in smart contracts: the orchestrating contract holds no write permission to any layer, and the agents hold no tool beyond read-only access to the L4 archive. A compromised agent gains no action rights. What it gains is the content of its own report — and the report is an input, to the traffic light and to the community reading it. The notary cannot be compelled to forge the register; nothing constrains what it says it saw. The boundary is stated exactly in 5.8.

---

## 5. Core Mechanisms

*My identity is my fortress.*

Four mechanisms form the operational core of BeTrueCore.

### 5.1 Anti-Collusion Protocol + ZK — Protection of the Moment of Choice

The anti-collusion protocol (Circom/Groth16, MACI pattern) makes a choice unprovable *after the fact*: an intermediate choice is cryptographically indistinguishable from the final one, so no participant can produce evidence of how they chose. Only the final choice counts. This does not reach a third party who watches the choice being made, or who holds the participant's message key — see 5.7.
```
Session open
     ↓
Participant submits encrypted choice (rotating key)
    ↓
Participant may rotate key + submit new choice (up to the message limit)
    ↓
TIME LOCK — session closes
    ↓
Only FINAL choice counts (all previous keys invalidated)
    ↓
Anti-collusion coordinator publishes result + ZK correctness proof
     ↓
Coordinator cannot falsify — fraudulent proof rejected by verifiers
```

### 5.2 VWU — Mathematical Weight of Participation

Vote Weight Unit is a dynamic participation weight assigned to each participant. Non-transferable, non-marketable, invisible to other participants. Accumulates through quality of judgment — not capital or status.

Public interface (inputs → output):

| Input | Description |
|---|---|
| `steps_completed` | Depth of the seven-step participation cycle (0–7) |
| `prompt_submitted` | Whether the participant submitted a prompt |
| `prompt_in_agenda` | Whether that prompt entered the TOP-3 agenda |
| `dilemma_support` | Support level per agenda dilemma; the scale is protected |
| **Output** | **Description** |
| `vwu_delta` | Signed change to participant VWU balance; never falls below the non-burnable base of 1 |

Contribution composition is public: Activity 40% + Utility 60%. The formula itself is protected in the master document (OpenTimestamps SHA-256) — component limits, the support-level scale, and the memory and adaptation coefficients are resolved internally. The Harmony Agent traffic-light verdict is not part of this computation: it is an ethical indication displayed by the Panorama, applied to each side of a dilemma separately — Option A and Option B alike — while silence receives no colour at all (5.4). It does not affect participant weight. Inputs and output are publicly disclosed — sufficient for integration. Full specification available to verified partners.

**Rational filter.** The goal and the time limit are identical for every participant. If a participant makes mutually exclusive or purely chaotic choices, the system records this as gamification abuse and the rating is reduced. This is the only mechanism that reduces a rating — and it never falls below the non-burnable base of 1.

**Silence is a sovereign decision.** VWU reflects only the days on which a participant was genuinely active. Absence reduces neither the rating nor the next session's delta: the rating is frozen for that period. Inactive days are reported to the participant alone, as potential gains forgone — for example, that over the last 90 days they did not take part in 15 sessions, during which their rating stood still.

Six status levels: SOLO → SELFLY → UNIVERSAL → HONORIS → LUMINARE → VERITAS_ZK.

### 5.3 Ethical Priority Map — 736 Points

23 Asilomar Principles × 32 TDSH parameters = 736 intersections. Each intersection is a formal rule for reading a session outcome. The map is applied to the result of a vote and to nothing else — not to the text of a prompt, not to a participant's choice, and not to the conduct of the agents. One agent of the nine, the Harmony Agent, carries this work (5.4, 6).

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

What the Research receives: the Panorama — the same cryptographically sealed result every participant receives. Nothing more. No intermediate results, no participant identities, no influence over the session. A commissioner is a recipient of the result and is therefore one of the parties from whose perspective the assessment in 5.6 is made.

**What the Panorama shows.** At the head of it: all participants, as a count and as the sum of the weight they carry together — the whole roster fixed for this session. Below it, the outcome in three rows: Option A, Option B, silence. Each of the three carries a count and, beside it, the sum of the weight behind that count. The head is the sum of the three, by people and by weight alike, so nothing falls out and nothing is left for the reader to work out.

Silence covers two kinds of participant at once: those who took part and made no choice, and those who did not take part in this session at all. Both are in the roster, so both are in this row. The traffic-light indication is applied to each side of the dilemma separately: Option A receives a colour of its own and Option B receives a colour of its own, by one and the same measure — the same map, the same thresholds. A majority is not thereby right and a minority is not thereby wrong; a majority does not press down on anyone. There are no winners and no losers, there is self-knowledge. Silence never receives a colour, and the weight behind it is added to neither side: it indicates how much the dilemma itself mattered, and the one who stays silent may well be a participant of high standing. If no one chose at all, the Panorama shows exactly that — the figures in full, both sides empty, no colours — and what a community declined to take up is itself a reading of that community's living interest.

These figures belong to the community, not to any participant: they establish the standing of a community's judgment without naming anyone, and no individual gains a name or a priority from them. One consequence is stated here rather than discovered later: the figures can be added and subtracted, so the number who stayed silent is knowable by any reader — indeed it is published outright. That is accepted, because silence is a recorded state of the protocol and a sovereign signal in its own right — not missing data to be concealed. What remains unpublished is which participant stands behind which figure, and that is what L0 and L1 protect.
This is not advertising. It is clean collective signal as a service.

### 5.5 ZK Security Boundary — Quantum Horizon

BeTrueCore's L1 architecture uses zero-knowledge proofs based on Groth16/BN254. This raises two fundamentally distinct security questions that must not be conflated.

**Current protection: opacity as a formal property.** The zero-knowledge property guarantees that no observer — human, AI analyser, or quantum system — can extract information about who voted and what they chose from a published proof. This follows not from computational hardness but from the existence of a simulator capable of generating indistinguishable proofs without knowledge of the witness. Past votes are permanently protected, regardless of future computational capabilities.

**Quantum horizon: a threat to soundness, not to opacity.** Shor's algorithm on a Cryptographically Relevant Quantum Computer (CRQC) could solve the Elliptic Curve Discrete Logarithm Problem (ECDLP) underlying BN254, potentially enabling fabrication of new proofs — a soundness violation affecting future votes only. This threat is credible on a 2030–2035 horizon per NIST and G7 assessments. The migration path is defined: replacement of the L1 proof scheme from Groth16 to zk-STARK (based on collision-resistant hash functions; natively post-quantum). Levels L2–L5 remain unaffected — BeTrueCore's modular architecture was designed precisely to accommodate this substitution.

### 5.6 Data Protection Boundary — What the Law Counts, Not What the Proof Hides

As with the quantum horizon, two questions must not be conflated. The first is what the cryptography conceals. The second is what European data protection law counts as personal data — and the law asks its own questions, which no proof answers on its behalf.

**Three tests, applied to the tree of commitments.** The tree is the only set the protocol writes on-chain; a community label is derived separately and is not linked across communities. There is no roster to examine: no list of participants exists, by community or by person, and membership is published nowhere. The founders of a community do not know who joined after them. Against the tests:

- *No Record Isolation* — violated by construction. Every participant is a distinct leaf, so every record is unique. What carries the position is the further test the guidelines prescribe: whether a unique record can be matched to the attributes of a real person. It carries no demographic attribute, and the commitment — a hash of the national identification number and a secret held on the participant's device — cannot be recomputed without that secret.
- *No Linkage* — partial correspondence. Nullifiers do not link one person's sessions. Two links remain: the transaction is sent from the participant's own address, so one wallet links that person's sessions regardless of the nullifier scheme; and the chronology of Merkle root updates, published exactly, narrows the circle in a small community when set beside the gateway's own record of who verified and when.
- *No Inference* — under review. By protocol the collective decision, a traffic-light indication for each side of the dilemma, and the whole of the Panorama (5.4) leave the system: the roster total at its head, and three rows below it — Option A, Option B and silence — each as a count and as the sum of the weight behind it. All of this is published by design, not as an artefact of the implementation, and the published surface is therefore wider than a pair of counts. What a series of them yields across sessions over one roster is assessed separately — the question is not whether a single session discloses a person, but what repeated exact figures over a small and stable community narrow down when set beside the chronology of root updates named under *No Linkage* above. The weight sums are the part of this surface not yet assessed at all, and they constrain more tightly than counts do: weight is individual and changes slowly, so a row's sum in a small community is a narrower fact than its count.

**Anonymity is assessed per party, not per dataset.** The same record can be anonymous for one party and personal for another. The relevant parties here are an observer of the chain, the e-government gateway that verifies the identifier, the application itself, other participants, and a Research commissioner (5.4).

**What is therefore not claimed.** BeTrueCore does not provide anonymisation in the legal sense. The tree of commitments is pseudonymisation, and pseudonymised data remains personal data. Nor does voluntariness change this: the application is established on a voluntary basis and a response to any dilemma is optional, but consent is a legal basis for processing, not a release from it. What is claimed is narrower and structural — the identifier never leaves the device; the commitment is what travels.

**Nor is completeness of the roster claimed as proved.** The tree is assembled off-chain and only its root reaches the contract, so the transition from one root to the next is not itself proved: no published artefact shows a new root to be the old one with exactly the announced commitments inserted. Until such a proof exists, a closed roster rests on trust in whoever computes the root, and this document says so wherever it calls the set fixed. The same holds at the other door: registration verifies no proof on-chain and restricts no caller, so an extra entry costs one call and nothing else — no work, no stake, no vouch, no synchronous ceremony. What the protocol does establish about the roster is the part that holds without this proof: a participant proves membership of a set without being named, the set does not change once mutual observation begins, and a missing record shows as a gap in an append-only log. The primitive still absent — a third-party-verifiable proof of set equality that discloses no counts — is stated as absent in the requirements table, marked `not established`, and is the one place where outside specialist work is needed.

The full position, with its sources and its one open point, is set out in `docs/AUTHORITY_CHAIN.md`, §11. The tests are named as the European Data Protection Board names them in *Guidelines 02/2026 on Anonymisation*, version 1.0 of 7 July 2026 — **the version adopted for public consultation; the final text may differ** — while the operative position remains Article 29 Working Party *Opinion 05/2014 on Anonymisation Techniques*.

### 5.7 Coercion Boundary — What Cannot Be Proved, and What Cannot Be Prevented

The mechanism of 5.1 is readily taken for protection against coercion. It is narrower than that, and the width is stated here rather than discovered later.

**What holds.** Inside the protocol perimeter, a defector is not identified — provided each participant chooses once and with their own key. No individual choice is published; the time lock keeps the distribution of choices out of sight while a choice is being made; and an earlier choice can be overwritten, so it proves nothing afterwards.

**What does not hold.** Whoever holds the message key sends the last message himself, and key rotation then serves him exactly as it would serve the participant. Nothing here reaches a coercer standing over the participant at the moment of choosing either. Both premises — observation at the moment of choice, and a key handed over — lie outside the protocol and are closed by no scheme in this architecture. The election literature closes the second with a fake key the coercer cannot distinguish from a real one (Juels, Catalano and Jakobsson); no such primitive is established here, and the gap is named rather than worked around.

**What a coercer can verify.** The choice is closed; the entry is not. A transaction is sent from the participant's own address, so a demand to abstain is checkable by looking — the forced-abstention case of the same literature, resting on the link recorded as partial correspondence under *No Linkage* in 5.6. Re-choice is bounded as well: the per-participant message limit exists against spam, and once spent within a session it is spent for the rest of that session.

**The shape of the claim.** Whoever can punish everyone needs to identify no one. The protocol does not make coercion fail; it removes the evidence that would let a coercer tell compliance from defection inside the perimeter. The same turn applies to prohibition: what is provided is non-identifiability of a participant, not immunity of a community to being shut out.

The same boundary, expressed for the contracts, is in `docs/AUTHORITY_CHAIN.md`, §12.

### 5.8 Injection Boundary — What the Observing Layer Reads, and What That Costs

The agenda belongs to the community. It follows that the text a session turns on is written by participants, and the L5 agents read it. Anyone who takes part can therefore place text in front of a language model, and that is the input surface of this layer.

**Why it is not prevented.** A language model draws no architectural line between an instruction and a datum: both arrive as one stream of tokens, and no reliable prevention mechanism exists today. Defence is architectural rather than interceptive — the surrounding system is built on the assumption that the model's instruction boundary will be crossed, and what is bounded is what a crossing can reach. (OWASP GenAI Security Project, *OWASP Top 10 for LLM Applications 2026*, 4 August 2026, entry LLM01.)

**What holds.** An agent steered by what it read gains no action. It holds no write permission to L0–L4; no shell, file or network tool exists in its session; its only channels are read-only. It can alter no record, no verdict, no participant's weight, and no membership of a session.

**What does not hold.** The content of the report. A successful injection changes what an agent says it observed, and the nine signals aggregate into the traffic light the community reads. The failure is a false account of a true record, not a forged record, and nothing in the observing layer detects it. The nine agents provide no redundancy against this, since all nine read the same session data; nor does the rubric grader, which is itself a model reading the report it scores.

**What is a defence.** Only what does not depend on a model. The contract bounds the values it will accept from the agents and refuses the rest before aggregation, and a refusal is counted and published, so a verdict resting on a reduced set is recognisable as one. And the session carries a commitment to the dilemma text, so a report can afterwards be read against the text that was in force.

**The shape of the claim.** The protocol does not make an injected report impossible. It removes the leverage such a report would need in order to become an action, and leaves it as testimony — bounded in form, aggregated by a rule no agent can change, checkable against a text fixed before the reading. A signal from L5 carries the standing of a witness statement, not of a proof, and no text of this project should present it as a measurement.

The same boundary, expressed for the contracts, is in `docs/AUTHORITY_CHAIN.md`, §13.

### 5.9 Control Boundary — What a Role Can Reach, and What Cannot Be Proved About Who Holds It

Several roles in this architecture are held by an address: the coordinator of the anti-collusion protocol (5.1), the address that writes the Merkle root, the address registered as the Harmony Agent in the matrix contract, the deployer of each contract. The question is not whether such roles exist — they do, and pretending otherwise would be the first error — but what they can reach, and what can be proved about who holds them.

**What holds.** A role is transferred in two steps, never in one: the current holder nominates, the nominee accepts, and until acceptance nothing has moved. Every nomination and every acceptance emits an event, so a change of hands is visible in the archive instead of being silent. No role reads an individual choice, alters a record already written, or changes a participant's weight; the bounds a contract places on the values it will accept hold against the role exactly as they hold against anyone else.

**What does not hold, and is not claimed.** That a role belongs to the community cannot be proved while an address holds it. It is disclosed, not proved: who holds the key is named publicly, and a reader is relied upon to look. No document closes this gap, and none is offered as closing it. A community has no legal personality and needs none — it comes into being on the initiative of any citizen, and the statutes of the association that operates the application are the association's, not the community's. To rest the claim on those statutes would cut the root of authority this architecture begins from: the root of a mandate is the decision procedure itself, not a register entry.

**How it becomes proved.** By the role disappearing. By Phase 3 of the pilot the community governs through the protocol itself, and there is nothing left for anyone to hold. This is not a limitation worked around — it is the direction the whole construction runs in, and the measure of its completion.

The same boundary, expressed for the contracts, is in `docs/AUTHORITY_CHAIN.md`, §14.

---

## 6. AI as Notary

*AI as notary, not judge.*

The observer principle is not a declaration of intent. It is an architectural property encoded in smart contracts.

| Agent | Reads | Decides | Function |
|---|---|---|---|
| Analyst × 3 | L4 archive — commitments and proof records | NEVER | Signal verification |
| Strategist × 3 | L4 archive — session results and audit log | NEVER | Ethical signal, risk signal, and the Harmony Agent's verdict proposal |
| Sentinel × 3 | L4 archive — records of all layers as archived | NEVER | Security monitoring |

The channel is the same for all three and it is the only one — the read-only
L4 gateway described in 4 above. No agent reads a layer directly.

A compromised Analyst sees ZK commitments — but cannot write to the VWU. A captured Strategist identifies coordination patterns — but cannot alter consensus outcomes. A compromised Sentinel stops flagging violations — and the material it would have flagged stays in the Celestia DA log for an independent reader, though it does not surface there on its own.

A fourth scenario belongs beside these three, and the three do not cover it: an agent that is not compromised at all, but steered by the text it was given to read. It writes nothing, alters nothing, and reports something that did not happen. That is the subject of 5.8.

**What the verdict is, and who computes it.** One agent of the nine — the Harmony Agent — reads the outcome of a dilemma, determines off-chain which cells of the 736-point map that outcome touches, and applies the map to each side separately. What it submits on-chain is its working: the cells, their weights, the counts of the result, and its own conclusion. The design does not take that conclusion on trust: `HarmonyAgent.sol` recomputes the verdict from the submitted cells by the map's own rule and records both — the agent's conclusion and the chain's recomputation, side by side — so that any divergence between them stays visible to a reader instead of being settled silently in favour of either. This is what `NEVER` in the Decides column means in practice: the agent has the standing of a witness whose testimony is checked, not of a judge whose finding is entered.

**What is not wired yet.** The recomputation above exists as a function and is not on the path a session actually takes. No contract of the package calls it: `finalizeSession` in `BeTrueCoreCore.sol` stores the two verdicts that arrive in the submitted result and compares them with nothing. So a coordinator may recompute and then finalize with different verdicts, and no check notices. Until finalization takes its verdicts from that computation, or refuses a result that disagrees with it, this section describes a function that is available rather than a guarantee that is enforced. It is recorded that way in the requirements table of `docs/AUTHORITY_CHAIN.md`, §14, and closing it is a revision of the finalization path.

**What the observational layer does not do: Sybil-resistance.** The Strategist reads aggregates, and an extra participant leaves no aggregate to read. The registry grows by a root computed off-chain, and the contract receiving that root cannot distinguish a root carrying the commitments of those who registered from one carrying a leaf nobody chose; registration itself verifies no proof on-chain. So there is no anomaly for an agent to notice, and no agent decides anything in any case — the `NEVER` column is architectural. Sybil-resistance at L0 rests on the national identifier checked at the e-government gateway, and the checking happens in the client, outside this protocol. It is an organisational guarantee, and it is named as one wherever this document claims it. Cheaper imitation of a human does not move this boundary: the substrate is a registry record, not a test telling a human from a machine, and forging it means forging the state's record rather than passing a test.

In the three scenarios above the attacker gains visibility — not power. In the fourth he gains neither, and gains instead a sentence in a report that people will read. That is less than power and more than visibility, and the architecture answers it by bounding what a report can reach rather than by preventing it (5.8).

The observational layer sees the reflection in the mirror. It cannot alter the mirror — not by moral intent, but by the structure of the environment. What it can do is describe the reflection wrongly, and that is why its description is testimony and not measurement.

---

## 7. The Ethical Architecture

*The mirror reflects. The notary bears witness. The matrix measures.*

736 points — not a list of rules. This is the grammar in which a collective outcome is read.

The Ethical Priority Map is built on the intersection of two systems: 23 Asilomar Principles — internationally recognised guidelines for safe AI — and 32 TDSH parameters — BeTrueCore's internal system of collective decision hygiene. The Cartesian product yields 736 intersections. Each is a formal rule for reading one aspect of a session outcome in a specific context. The map governs the reading of a result, not the conduct of an agent: the Harmony Agent applies it to the outcome of a dilemma, to each side separately, and the chain recomputes what the agent submits (6).

VWU is the measurement instrument within this architecture. It does not evaluate the participant's identity — it measures the quality of judgment over time. The matrix sets the ethical frame in which an outcome is read. VWU records the quality of the human signal. Together they form a closed loop: ethics defines the framework of observation, observation measures the signal, the signal returns to the system as accumulated collective knowledge.

Scale invariance is the key property of the architecture. 736 rules operate identically at the level of a small group and at the global level. The size of the community changes the volume of data — not the structure of measurement.

---

## 8. Implementation Status

Architecture, mathematical model, and technical specification are complete and timestamp-protected.

### 8.1 Research and Specification

- 12 academic preprints published on Zenodo (ORCID: 0009-0004-4841-594X)
- Master document: 19,012 words, protected by OpenTimestamps SHA-256 timestamp
- 736-point Ethical Priority Map formalised
- Evidential layer boundary defined (MAPPING_MODEL v0.9)
- ERC-8281 integration points identified at L1 and L3

### 8.2 Technical Implementation

Developer Package v0.3 includes six contracts — `BeTrueCoreCore.sol`, `VWUEngine.sol`, `EthicalMatrix.sol`, `HarmonyAgent.sol`, `Poll.sol`, `NINNullifierRegistry.sol` — two interfaces, `IBeTrueCore.sol` and `IBeTrueCoreAntiCollusion.sol`, and a Foundry test suite.

Damon Zwicker (ERC-8281 – Observation Commitment Protocol) reviewed the proposed integration of ERC-8281 into BeTrueCore and helped clarify the architectural boundary between BeTrueCore's private transition logic and ERC-8281's independently verifiable commitment layer. The discussion focused on the VoteProof observation envelope at L1 and the two-point commitment structure surrounding the Lit Protocol time-lock at L3. ERC-8281 provides an independently verifiable commitment layer for those observations and transitions without requiring access to BeTrueCore's private VWU inputs, internal protocol semantics, or governance logic.

Pavlo Tvardovskyi — author of ReceiptOS, a portable recomputable evidence substrate (DOI [10.5281/zenodo.21402444](https://doi.org/10.5281/zenodo.21402444)) — defined the evidential layer boundary through joint work on BeTrueCore Evidential Layer × ReceiptOS Mapping v0. ReceiptOS supplies recomputable proof references and nothing else — it does not produce, consume, or endorse VWU scoring.

*Note: This whitepaper is published under CC BY-NC 4.0. ReceiptOS remains independently licensed under CC BY 4.0.*

### 8.3 Prototype — BTC-Test

Prior to full cryptographic implementation, the protocol was validated on a live group. The BTC-Test pilot was conducted with a group of 21 participants — former classmates. Participants were presented with 13 dilemmas — covering topics of health, family, justice, security, heritage, technology, and faith — and asked to select the 3 most significant for the group. The three selected dilemmas became the session agenda.

The BTC-Lite protocol was used — a trust-based variant without blockchain. Participants received the dilemmas in a WhatsApp group and submitted their choices by SMS to the organiser's personal phone over the course of one day. Each participant received an anonymous number in return. The three dilemmas with the highest vote count became the agenda. Answers A/B for each dilemma were collected in the same format — at a time convenient for each participant. Results were published simultaneously for all at 20:00. VWU mechanics and the traffic-light verdict system were applied in full.

12 participants responded at least once. Group activity: 57%. The number responding differed from dilemma to dilemma — a response to any single dilemma was optional, as it is in the protocol — so the percentages in the table below are taken against the responses to that dilemma, not against the 12. Average group VWU: 4.51.

**Three dilemmas:**

| Dilemma | Simple Majority | Weighted Result | Verdict |
|---|---|---|---|
| Who should make a risky surgical decision — doctor or patient? | B — Patient (85.7%) | B — 92.1% | ✱GREEN |
| What is more important to leave children — property or values? | B — Values (100%) | B — 100% | ✱GREEN |
| Should a grown child's phone be monitored or trusted? | A — Monitor (75%) | A — 74.1% | ✱GREEN |

All three dilemmas returned a GREEN verdict — judgment is stable. Dilemma with greatest unity: Values. Dilemma with greatest discrepancy: Monitor.

Two limits of the prototype are recorded rather than smoothed over. One verdict was issued per dilemma, whereas the protocol issues one per side of a dilemma (5.4), and the pilot's figures do not allow the two colours to be reconstructed after the fact. The sum of weight behind each row was not collected either, so the Panorama cannot be rendered for this pilot at all — neither the roster total at its head, as a count and as the sum of the weight behind it, nor the three rows below it, each with its own sum beside its count. Only the counts above survive. What the pilot establishes is that the mechanics work on a live group, not that the Panorama in its present form has been tested.

The pilot confirmed: the mechanics work on a live group prior to technical implementation. The weighted result differs from simple majority — and this difference is perceived by the group as meaningful.

### 8.4 Current Stage and Roadmap

Current stage: TRL 2 → TRL 3

| Phase | Duration | Milestone |
|---|---|---|
| Phase 1 — Core | 1–2 months | Anti-collusion contract on testnet (MACI pattern, own implementation) + ZK identity circuit + on-chain registration verifier + VWU contract |
| Phase 2 — Integration | 2–3 months | Lit Protocol + Celestia DA + Optimism L2 deployment |
| Phase 3 — Pilot | 1–2 months | Closed pilot 50–100 users + full audit |

---

## 9. How to Contribute

BeTrueCore is at TRL 2 → TRL 3. Architecture, mathematical model, and specification are complete. Seeking a technical partner for core implementation.

**Critical path (MVP):**

1. Anti-collusion smart contract deployment (testnet)
2. ZK identity circuit (Circom) — state ID commitment + nullifier
3. On-chain verifier for the registration proof — without it registration accepts any value and the circuit of point 2 guards nothing
4. VWU calculation contract integration

Without these four components the system does not function. Celestia and Lit Protocol — Phase 2.

**The one open primitive.** Beyond the critical path, one requirement has no implementation to assign: a proof that the transition of the Merkle root inserted exactly the announced commitments and nothing else, verifiable by a third party without disclosing counts. It is the `not established` row of the requirements table, it is what would make an added leaf visible, and it is not a task for one person. A contributor who recognises this problem is the contributor this project is looking for.

**Technology stack:**

| Layer | Language / Framework |
|---|---|
| Smart contracts (L1–L2) | Solidity ^0.8.24 + Foundry |
| ZK circuits | Circom 2.0 + snarkjs |
| MPC / Identity | Web3Auth MPC Core Kit v3+ |
| Time-lock | Lit Protocol SDK v6+ |
| Data availability | Celestia node v0.12+ |
| Backend orchestration | TypeScript (Node 20 LTS) |
| AI agents | Python 3.11+ + FastAPI |

**What is open:**

- Full smart contract suite (Developer Package v0.3)
- Anti-collusion integration specification (MACI_ENGINEER_PACKAGE.md)
- Evidential layer boundary model (MAPPING_MODEL.md)
- Architectural foundation (ARCHITECTURE_FOUNDATION.md)
- 736-point Ethical Priority Map (Excel + Solidity)
- Foundry unit tests

**What is protected:**

- VWU component limits, support-level scale, memory and adaptation coefficients, non-linear growth factor, and full formula.
- Master document (available to verified partners).

If you are a Solidity / Circom / ZK developer interested in sovereign collective intelligence — open an Issue or reach out via ethresear.ch: [Dede-Qorqud](https://ethresear.ch/u/Dede-Qorqud)

---

## 10. References

**Protocols:**

- MACI anti-collusion pattern (Circom/Groth16) — repository archived August 19, 2026
- Asilomar AI Principles — [futureoflife.org/ai-principles](https://futureoflife.org/ai-principles/)
- Juels, A., Catalano, D., Jakobsson, M. *Coercion-Resistant Electronic Elections.* Cryptology ePrint Archive, Report 2002/165. Read 19 October 2026.

**Philosophical and scientific sources:**

- Kuran, T. (1995). *Private Truths, Public Lies.* Harvard University Press.
- Foucault, M. (1975). *Surveiller et punir.* Gallimard.
- Zuboff, S. (2019). *The Age of Surveillance Capitalism.* PublicAffairs.
- Gödel, K. (1931). *Über formal unentscheidbare Sätze.* Monatshefte für Mathematik und Physik.
- Poincaré, H. (1908). *Science et méthode.* Flammarion.

**Repository and publications:**

- GitHub: [github.com/Dede-Qorqud/BeTrueCore](https://github.com/Dede-Qorqud/BeTrueCore)
- Paragraph: [@betruecore](https://paragraph.com/@betruecore)
- ethresear.ch: [Dede-Qorqud](https://ethresear.ch/u/Dede-Qorqud)

---

*THE MIRROR REFLECTS • THE NOTARY BEARS WITNESS • THE MATRIX MEASURES*