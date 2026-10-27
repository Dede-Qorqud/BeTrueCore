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
a cryptographic record of what a fixed set of participants decided — without
revealing who chose what.

One word is avoided here on purpose. This is not a proof of quorum: the
protocol sets no threshold of participation, and none of its contracts checks
one. Answering a dilemma is not compulsory, silence is a recorded state rather
than a shortfall, and where nobody chose at all the Panorama publishes exactly
that and no verdict is issued. What the record carries is the roster fixed
before the session, the three rows of the outcome, and a verdict on each side —
not an assertion that enough people took part. A relying party that needs a
threshold applies its own to those figures; the protocol supplies the figures
and takes no view.

This proof has three properties the PDF-based approval lacks:

**1. Verifiability at the moment of transaction.**
Any counterparty can verify the ZK-proof on-chain without contacting
BeTrueCore infrastructure. Verification is stateless, instant, and
trustless.

**2. Scope binding.**
The proof encodes the decision's parameters: what was decided, in what fixed
set of participants, within what time window. An agent mandate derived from this
proof inherits these scope constraints — equivalent to PSD2 dynamic linking,
applied to a collective decision rather than a payment.

**3. Privacy preservation.**
The proof attests that the collective decided — without exposing the
identity of any participant or the distribution of individual votes.
The decision is transparent. The citizens are secret. What that sentence
covers, and what it does not, is set out in §11 for disclosure, §12 for
coercion, §13 for what the observation layer is exposed to, and §14 for the
roles that hold the measures by which a decision is read.

This directly maps to the M-Trust chain:

| M-Trust Layer | BeTrueCore Component |
|---|---|
| Authoritative source | ZK-nullifier registry (L0) — one citizen, one identity |
| Collective principal | Community of verified participants (L0+L1) |
| **Organisational approval** | **ZK-Beschluss: L1 proof of the collective decision and of the set it was taken in ← fills the gap** |
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
- Anonymisation in the legal sense of EU data protection law — the tree of
  commitments is pseudonymisation, and pseudonymised data remains personal
  data (see §11)
- Resistance to coercion in the sense the election literature gives that term.
  What the protocol holds is narrower and is stated exactly in §12
- Protection of the L5 observation agents against text written to steer them.
  No current technique prevents prompt injection. What the architecture bounds
  is the consequence, and §13 states where that bound ends
- Proof that the roles of the protocol are held by the community itself. Four
  addresses hold the measures by which a session is read — who is in the set,
  what a participation is worth, who may judge, and when a session opens and
  closes. Each can now be passed on and each passing is recorded, which is what
  §14 establishes; that the holder is the community rather than one person is
  organisational, and no part of this architecture proves it

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
- Report in a structured signal format, which the contract aggregates and the
  community reads on the Panorama — there is no human review layer above the
  participants, and the agenda, the choices and the reading of the result
  belong to the community itself
- Write nothing — ever

They also do not detect Sybil entries, and the point is worth stating because
observation is readily mistaken for a remedy. An extra participant leaves no
aggregate for an agent to read: registration verifies no proof on-chain, the
tree is built off-chain, and a root carrying a leaf nobody chose is
indistinguishable from an honest one. There is therefore no anomaly to notice.
What the price of an extra entry rests on is organisational and lies outside
this layer — the client that checks the number at the e-government gateway, and
whoever computes the root. See the first two rows of the table in §14.

What the report is, said once: an input. One of the nine — the Harmony Agent —
reads the result of the vote as the Panorama shows it, chooses which cells of
the 736-point map the dilemma touches, applies the map to each side of the
dilemma separately, and submits the cells, the scores and its own conclusion.
`HarmonyAgent.sol` does not take that conclusion: it recomputes the verdict
from the submitted cells and scores and records both, side by side, so that any
divergence between them stays in the archive permanently. That recomputation is
not on the path a session takes — no contract calls it, and `finalizeSession`
stores the verdicts arriving in the submitted result without comparing them
with anything — so the verdict a session carries is the agent's conclusion, and
the requirements table in §14 records this as not established on the
finalization path. An agent that can alter nothing can still be wrong about
what it reports, and the text it reads is written by participants. That is the
subject of §13; who may hold the role that submits at all is the subject of §14.

The constitutional principle is unchanged across all contexts:

> *"AI is the notary. The human is the author.
> The notary cannot become a judge: it has no technical mechanism to forge
> the author's verdict."*

The principle holds for the verdict and not for the testimony. No mechanism
lets an agent write the author's verdict; nothing constrains what the agent
says it saw. §13 states that boundary exactly.

In the M-Trust framework, the L5 layer maps closest to Layer 8 (accountability)
— but as an observer of the process that produces the action receipt, not as
the issuer of that receipt. The ZK-cryptography issues the receipt. L5 watches
whether the process was clean.

---

## 9. Scope and Current Status

**What exists today (Phase 1):**

- ZK identity circuit: `circuits/NINCommitment.circom` + `circuits/NINIdentityProof.circom` — v0.1, plus `circuits/lib/BinaryMerkleTree.circom`
- On-chain ZK registry: `contracts/NINNullifierRegistry.sol` — Merkle root and nullifier registry; written, with no verifier deployed against it yet
- Core interface and implementation: `src/IBeTrueCore.sol` + `src/BeTrueCoreCore.sol` — sessions, the roster fixed at open, the Panorama rows and the credits
- Anti-collusion contract: `src/IBeTrueCoreAntiCollusion.sol` + `src/Poll.sol` — v0.1
- VWU engine: `src/VWUEngine.sol` — v0.8
- Ethical matrix: `src/EthicalMatrix.sol`
- Harmony orchestrator: `src/HarmonyAgent.sol`
- Foundry unit tests: `test/BeTrueCore.t.sol`
- L5 implementation specification: `docs/L5_MANAGED_AGENTS.md`

**What the ZK-Beschluss provides to an M-Trust-compatible system:**

A machine-readable, on-chain verifiable record that:
- The participants were verified individuals, drawn from a roster fixed before the session opened (L0). No threshold of participation is asserted, because the protocol sets none and checks none — see §5. A relying party that needs a threshold applies its own to the published figures
- A specific decision was reached under defined parameters (L1)
- No individual choice is disclosed by the published record; the fact that an
  address submitted a transaction is not concealed by the protocol (see §11)
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

## 11. Personal Data: The Legal Reading of the Architecture

Cryptography does not decide what counts as personal data. European data
protection law decides, and it asks its own questions: does the information
relate to a natural person, and is that person identified or identifiable by
means reasonably likely to be used. This section states BeTrueCore's position
against those questions, independently of the proofs.

**Anonymity is assessed per entity, not per dataset.** The same record can be
anonymous for one party and personal for another, so the relevant perspectives
have to be named. For BeTrueCore they are: an observer of the chain; the
e-government gateway that verifies the national identification number (NIN);
the application itself; other participants in the same community; and the
people who founded it. The position below is stated for each where they
differ.

**No roster exists.** There is no list of participants — not by community, not
by person. A community is founded by a handful of people who give it a name;
after that the social link inside the application ends. A new participant
installs the application and enters the community alone — nobody admits them.
Membership is therefore unknown to everyone, outside and inside alike: the
founders do not know whether three people or four joined after them. This is a
property of the construction, not an unfinished feature, and membership is
published nowhere.

**The identifier is consumed once and discarded.** The NIN is verified through
the e-government gateway at registration and stays on the device; key material
does not leave layer L0. The gateway learns that a person registered — and
nothing about which community that person entered or what was later decided
there. What leaves the device is a commitment: a hash of the NIN and a secret
held on that device. Hence the operative sentence: *who participates may be
known; how they participate, and in which community, is not.*

**The only set on-chain is the tree of commitments.** A community label is
derived separately and is not linked across communities. The three tests below
are therefore applied to that tree — there is no membership register to
examine.

| Test | Position | Status |
|---|---|---|
| No Record Isolation | Violated, and openly so: every participant is a distinct leaf, so every record is unique. What follows is the further test the guidelines prescribe — whether a unique record can be matched to the attributes of a real person. It carries no demographic attribute, and the commitment cannot be recomputed by a third party without the device-held secret. | violated; anonymity rests on the further test |
| No Linkage | Nullifiers do not link one person's sessions, and no community label crosses between communities. Two links remain. The transaction is sent from the participant's own address, so one wallet links that person's sessions regardless of the nullifier scheme; submitting through a third-party relayer does not close this link. Under ERC-4337 the submitted object carries the originating account in its `sender` field — present in the public mempool, in the on-chain `PackedUserOperation`, and in the signed hash — so relaying moves the observable identifier from the fee payer to the account, where it persists across sessions. No primitive closing this link is established here. And the gateway's own record of who verified and when, set beside the published chronology of Merkle root updates, narrows the circle in a small community. | partial correspondence |
| No Inference | The claim that counts are withheld is withdrawn: it described an earlier design. The Panorama publishes by design: the roster total at its head, as a count of people and a sum of weight, and three rows beneath it — Option A, Option B and silence — each as a count and a sum of weight, with a traffic light on each of the two sides and none on silence. The head is not a fourth figure in the chain: the three rows account for the whole roster, by people and by weight alike, because silence covers those who entered and chose neither option and those who did not take part at all. The roster itself is fixed when the session opens and the contract refuses a result whose rows do not add up to it — which catches a result that drops a participant or adds one, and proves nothing about who stood where. Silence therefore has a figure of its own rather than being inferred, which is the point of publishing it; the consequence that the number who stayed silent is knowable is accepted deliberately, and what stays closed is which participant was silent. Two further quantities make the reconstruction sharper than the sums alone did: individual weights are published one change at a time against each commitment, and the counts now say out of how many people each sum was composed. In a community of a handful of people that is usually enough to resolve who stood where, and the chain supplies no name to attach to it — that link, where it exists, comes from acquaintance outside the protocol. The figures are not removable: they are what the Panorama shows and what lets a third party recompute the result while set equality remains unproven. See §14 for the missing primitive. | violated by design; see §14 |

**Voluntariness is not an exemption.** The application is established on a
voluntary basis, in the form of a non-profit association, and a response to any
dilemma is optional. None of this places the processing outside the Regulation:
consent is a legal basis for processing, not a release from it. The claim made
here is a different one — the architecture is minimal by construction. The NIN
never leaves the device; the commitment is what travels.

**One point remains open.** The nullifier registry accepts a proof against the
current Merkle root only, and the chronology of root updates is published
exactly. In a small community that chronology narrows the circle
probabilistically — not to a single person, since any leaf in the tree can
produce a valid proof. A window of accepted roots is the structural answer to
this; it is recorded as an open item in the repository audit and is not closed
by an edit to this document.

**Sources for this section.** Article 29 Working Party, *Opinion 05/2014 on
Anonymisation Techniques* — the operative position. European Data Protection
Board, *Guidelines 02/2026 on Anonymisation*, version 1.0, adopted 7 July 2026
— **the version adopted for public consultation; the final text may differ.**
The three tests above are named as that version names them. Read in that order:
what is in force, then where it is moving.

---

## 12. Coercion: What the Protocol Holds and What It Does Not

A collective decision is worth proving only if the signals it aggregates were
given freely. The question that follows is therefore not a question about
cryptography: can a participant be pressured, and would the protocol show it?

**The exact claim.** Inside the protocol perimeter, a defector is not
identified — provided each participant chooses once and with their own key.
The published record carries no individual choice; the time lock keeps the
distribution of choices out of sight while a choice is being made; and a
choice made earlier in the session can be overwritten, so an earlier one
proves nothing. That is the whole of the claim, and it is narrower than
resistance to coercion.

**What lies outside the perimeter.** Two premises are external, and no scheme
in this architecture closes them:

- *Observation at the moment of choosing.* Someone standing over the
  participant sees the choice before any encryption applies to it.
- *A key handed over.* A coercer holding the message key sends the last
  message himself, and key rotation then works for him exactly as it would
  for the participant.

The literature closes the second with a fake key the coercer cannot
distinguish from a real one (Juels, Catalano and Jakobsson). No such
primitive is established here. The gap is named rather than worked around,
on the same footing as the missing primitive named at L1.

**What a coercer can check.** The choice is closed; the entry is not. A
transaction is sent from the participant's own address, so whoever knows that
address sees that the person entered this session, and a demand to abstain is
checkable by looking. This is the forced-abstention attack of the same
literature, and it rests on the link already recorded as partial
correspondence in the No Linkage row of §11. Re-choice has a bound of its own:
the per-participant message limit, needed against spam, is spent for good once
exhausted, so a coercer who has the cap spent in his presence closes re-choice
for the rest of the window.

**The shape of the claim, stated once.** Whoever can punish everyone has no
need to identify anyone. The protocol does not make coercion fail; it removes
the evidence a coercer would need to tell compliance from defection inside the
perimeter. The same turn applies to prohibition: what the protocol provides is
non-identifiability of a participant, not immunity of a community to being
shut out.

The corresponding statements in the code are at RECEIPT-FREENESS GUARANTEE —
AND ITS LIMIT in `src/Poll.sol`, at CORE PROPERTY — RECEIPT-FREENESS in
`src/IBeTrueCoreAntiCollusion.sol`, and at `submitChoice` in
`src/BeTrueCoreCore.sol`.

---

## 13. Injected Text: What the Observation Layer Is Exposed To

The protocol gives the agenda to the community. That is the architecture's
purpose, and it has a consequence that has to be stated rather than discovered:
the text a session turns on is written by participants, and the L5 observation
agents read it. An outsider who takes part can therefore place text in front of
a language model. This section states what that does and does not reach.

**Why it cannot be prevented.** A language model draws no architectural line
between an instruction and a datum; both arrive as one stream of tokens, and
there is no equivalent of a parameterised query. No reliable prevention
mechanism exists today. The practitioner consensus is that defence is
architectural rather than interceptive: the surrounding system is built on the
assumption that the model's instruction boundary will be crossed, and what is
bounded is what a crossing can reach. (OWASP GenAI Security Project, *OWASP Top
10 for LLM Applications 2026*, version 2026, 4 August 2026, entry LLM01; read
20 October 2026.) This architecture claims no prevention.

**The exact claim.** An agent steered by text it read gains no action. It holds
no write permission to any structure in L0 through L4; the orchestrator
contract that coordinates it holds none either; the pre-built tool set is not
declared on the agent, so no shell, file or network tool exists in its session;
and the only channels it has are read-only gateways. It cannot alter a record,
a verdict, a participant's weight, or the membership of a session. Injection
does not become action here, because at this layer there is no action to take.

**What it does change.** The content of the report. The nine agents return
signals; the Harmony Agent reads the result of the vote, selects the cells the
dilemma touches and submits the scores with its own conclusion; `HarmonyAgent.sol`
recomputes the verdict from those cells and scores and records both. A
successful injection changes what an agent says it observed — the cells it
names and the scores it reports — and the failure that follows is a false
account of a true record, not a forged record. What the recomputation
establishes is narrower than it looks: it proves the published verdict follows
the rule from the figures submitted, and proves nothing about whether those
figures describe the session. The same source classes this separately, as
incorrect evidence consumed by a downstream component (*ibid.*, entry LLM07).
Nothing in the observation layer detects it. The divergence between the agent's
conclusion and the recomputed verdict is a trace of a steered agent rather than
a detection of one — and it is preserved only where that recomputation is run.
No contract calls it today, so a session finalized without it leaves the agent's
conclusion standing alone, with nothing beside it to diverge from, and the one
trace this section relies on is absent. The requirements table in §14 records
that as not established on the finalization path.

**Two things that are not defences, named so they are not mistaken for any.**
The nine agents are isolated from one another, which bounds a fault in one
session; it does not bound an injection, because all nine read the same session
data and text that steers one reaches the other eight unchanged. And the grader
that scores a report against the TDSH rubric is separated in context, not in
trust: it is itself a model, and it reads the report the agent produced,
including any text the agent carried over.

**What is a defence.** Everything that does not depend on a model. The contract
bounds the values it will accept from the agents — a cell coordinate must lie
inside the 23 × 32 matrix and a score inside 0 to 100 — and refuses the rest
before aggregation. A refused entry is counted and published, so a verdict
resting on a reduced set is recognisable as one, and silence here is recorded
rather than inferred, on the same principle that governs a participant who did
not answer. These checks do not make a report true. They keep a report from
reaching anything but the aggregate it is meant to reach, and they keep its
refusal from passing unseen.

**What makes a report checkable afterwards.** The session carries a 32-byte
commitment to the dilemma text, published when the session opens. It fixes
which text was in force, so a report can later be read against the text the
agent actually read, and a text substituted afterwards does not match. Open
item: which commitment function is used, and where the text itself is
published, are not fixed anywhere in the code. Until they are, the commitment
binds the text the coordinator supplied — not the text the community chose. The
second half of the same gap: nothing links the dilemma opened at L1 to the one
opened at L2, and nothing shows that either came from the agenda the community
selected.

**The shape of the claim, stated once.** The protocol does not make an injected
report impossible. It removes the leverage such a report would need in order to
become an action, and leaves it as testimony — bounded in form, aggregated by a
rule no agent can change, and checkable against a text that was fixed before
the reading. A signal from L5 carries the standing of a witness statement, not
of a proof, and no text of this project should present it as a measurement.

The corresponding statements in the code are at the input-surface section and
the constitutional constraint in `docs/L5_MANAGED_AGENTS.md`, at the header
block and `computeFinalVerdict` in `src/HarmonyAgent.sol`, at `_cellKey` and
`triggerCell` in `src/EthicalMatrix.sol`, at `encrypted_data` and
`dilemma_hash` in `src/IBeTrueCoreAntiCollusion.sol`, and at the header block
and `openSession` in `src/BeTrueCoreCore.sol`.

---

## 14. Capture of the Roles: What the Protocol Establishes and What It Assumes

The architecture states that the coordinator and the operator are the community
itself and that no role stands above the participants. That statement is a
claim about intent. This section states what the code establishes, which is a
narrower and more useful thing: who can hold a role, how a role passes, what
the archive records when it passes, and what a holder can do that nothing
checks.

**The roles, and what each one decides.** Four addresses hold something a
session is read by. None of them can cast a choice, alter a recorded choice, or
see an individual choice; what they hold is the measures.

| Role | Where | What it decides |
|---|---|---|
| Registrar of the set | `contracts/NINNullifierRegistry.sol` | Which commitments are in the tree at all, and which contract may spend a nullifier |
| Registrar of the measure | `src/VWUEngine.sol` | Which contract may credit a participation, and therefore what a participation is worth |
| Registrar of the judgment | `src/EthicalMatrix.sol`, `src/HarmonyAgent.sol` | The 736 cells a verdict is computed against, and which contract may write the audit trail or compute a binding verdict |
| Coordinator | `src/Poll.sol`, `src/BeTrueCoreCore.sol` | When a session opens and closes, and which roster and which credits are submitted for it |

**How a role passes.** In two steps, in every file: the acting holder names a
successor, and the successor takes the role by its own call. The second step is
not a formality — it is how the successor shows it holds the key, and it is
what makes a role impossible to lose to a mistyped address. There is no third
party who can move a role, and the deploying address, which receives the roles
at deployment, retains nothing afterwards. The cost is stated rather than
hidden: a lost key cannot be recovered by anyone, and the only remedy is
redeployment.

**What the archive records.** Both steps emit an event naming both addresses,
so a handover is never silent. Five of the six carry the counter of the file
they live in — polls, sessions, root updates, applied sessions, loadings of the
map — so a reader can place a handover in the run of events rather than only in
time. The sixth, in `src/HarmonyAgent.sol`, carries no counter: that contract
keeps none of its own, and every verdict it writes is already keyed by session.
A handover there is placed between two sessions by the block it sits in, which
is coarser and is stated here rather than left to be discovered.

**A handover during an open session.** Not blocked, deliberately. Finalisation
checks the current holder only, so a session opened by one holder is closed by
the next; the alternative would leave a session that no one can close. What the
code cannot ensure is that the successor can decrypt what was locked for its
predecessor: the decryption role belongs to a threshold quorum on an outside
network, and matching that quorum to a new address is organisational.

**What is checked and what is not.** The table below is the substance of this
section rather than a caveat to it: four requirements rest on trust in whoever
holds a role, and two are established by the code.

| Requirement | Layer | Assessment | Checked by |
|---|---|---|---|
| A credit to a participant follows from what that participant did | L2 | not established | nothing. The weight is computed off-chain and only its result crosses into the chain, so a credit is a number the coordinator asserts |
| A new Merkle root adds exactly the commitments declared | L1 | not established | nothing. The tree is assembled off-chain; the chain records that a root changed and never what the change contained |
| The holder of a role is the community rather than one person | all | not established, and not a document away | nothing, while a role is held by an address — and no statute closes it either. The association that runs the application has a constitution; the community inside it has no legal personhood by design, is founded on the initiative of any citizen, and requires no document at all. That is the point of the root this architecture chooses: authority begins at the procedure of decision, not at a register entry. What is honest today is disclosure rather than proof — who holds each key, published. What establishes the claim is not a document but the disappearance of the role: by Trial 3 the community governs through the protocol itself, and there is nothing left to hold. See the three trials at the coordinator field in `src/Poll.sol` |
| A verdict was computed by the rule the map states | L2 | not established on the finalization path | HarmonyAgent.computeFinalVerdict recomputes the verdict from the submitted cells and scores and records both its own result and the agent's conclusion, so a divergence there stays in the archive. No contract calls it: finalizeSession in BeTrueCoreCore.sol stores the verdicts that arrive in the submitted result and compares them with nothing. The recomputation stands beside the path, not on it, and a coordinator may compute one verdict and finalize another
| A role passed, and when | all | documented primitive | the handover events, each carrying the counter of its file |
| The tally is correct without publishing the figures it is computed over | L1 | not established | nothing. The same class of missing primitive as the proof of set equality named at L1; it is what would close the reconstruction described in §11 |

**The shape of the claim, stated once.** Capture of a role does not yield a
forged choice, a forged record, or sight of who chose what. It yields the power
to set the measures by which choices are read — what a participation was worth,
who was in the set at all. The protocol makes that power nameable, passable and
visible in the archive; it does not make its exercise provable. Naming a role
after the community does not establish that the community holds it, and no text
of this project should present it as though it did.

The corresponding statements in the code are at the coordinator field and the
handover section in `src/Poll.sol`, at the registrar field and the handover
section in `contracts/NINNullifierRegistry.sol`, `src/VWUEngine.sol`,
`src/EthicalMatrix.sol` and `src/HarmonyAgent.sol`, and at the coordinator
field and the handover section in `src/BeTrueCoreCore.sol`.

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
- Ethereum Improvement Proposals. *ERC-4337: Account Abstraction Using Alt Mempool.*
  eips.ethereum.org/EIPS/eip-4337. Reviewed 13 October 2026.
- Juels, A., Catalano, D., Jakobsson, M. *Coercion-Resistant Electronic
  Elections.* Cryptology ePrint Archive, Report 2002/165. Read 19 October 2026.
- Buterin, V. (2021). *Moving beyond coin voting governance.*
  vitalik.eth.limo/general/2021/08/16/voting3.html, 16 August 2021.
  Read 22 October 2026. Cited for the non-coin-driven direction and for the
  limits of limited governance; its figures on issuance predate the move to
  proof of stake and are not relied on here.
- Guliyev, F. (2026). *From Coordination Collapse to Collective
  Wisdom: Extending the VWU Model.* Zenodo. DOI: 10.5281/zenodo.22179301
- Guliyev, F. (2026). *Threshold and Witness: From a Model of
  Collective Behaviour to an Architecture of Collective Judgment.* Zenodo.
  DOI: 10.5281/zenodo.22537058
- [BeTrueCore Architecture Foundation](./ARCHITECTURE_FOUNDATION.md)
- [L5 AI Agent Implementation](./L5_MANAGED_AGENTS.md)

---

*BeTrueCore Modular System — Web3 Intuitive Symmetry Methodology (Web3-ISM) v1.2*
*Repository: [github.com/Dede-Qorqud/BeTrueCore](https://github.com/Dede-Qorqud/BeTrueCore)*
*Timestamped via OpenTimestamps (SHA-256)*
