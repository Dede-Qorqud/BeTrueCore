# BeTrueCore Mapping Model
## Evidential Layer Boundary Definition

**Version:** 0.9 — aligned with the public-surface audit of 04.10.2026, the data-protection lens of 10.10.2026, the transaction side-channel lens of 10.10–13.10.2026, the statistical-disclosure lens of 14.10.2026, the prompt-injection lens of 20.10.2026 and the control-capture lens of 22.10.2026
**Repository:** github.com/Dede-Qorqud/BeTrueCore

---

## Overview

The Mapping Model defines the evidential layer boundary between BeTrueCore's internal architecture and external systems. It specifies what data crosses each layer boundary, in which direction, and under what cryptographic guarantees.

---

## Layer Architecture

```
L0  Identity Input          NIN-code ZK-commitment + session timing
     ↓
L1  Cryptographic Proof     ZK-SNARKs + anti-collusion protocol (Circom/Groth16) + ZK nullifier + Lit Protocol MPC
     ↓
L2  Execution               Optimism L2 — smart contract execution; the VWU
                            calculation runs in the protocol, L2 receives its
                            result (lens B5)
     ↓
L3  Lock                    Lit Protocol — time-lock, information symmetry until reveal
     ↓
L4  Data Availability       Celestia DA — public audit log (immutable, independent)
     ↓
L5  AI Agent Layer          Analyst × 3 + Strategist × 3 + Sentinel × 3
                            READ-ONLY — no write access to any data structure
```

---

## Boundary Definitions

### L0 → L1 Boundary

| Data | Direction | Format | Guarantee |
|------|-----------|--------|-----------|
| NIN-code ZK-commitment | L0 → L1 | bytes32 hash | State ID verified |
| Session timing | L0 → L1 | uint256 timestamp | Liveness proof |

**What does NOT cross:** Raw NIN-code, state identifier plaintext.  
**Guarantee:** No raw NIN-code or state identifier ever leaves L0.

**Withdrawn: behavioral channel.** An earlier design verified the participant
biometrically, and a behavioral-entropy field remained in this table after the
move to the NIN-code. It is removed. Three reasons, in order of weight. The
protocol cannot verify where a client-side measurement came from: a zero-
knowledge proof establishes knowledge of a value, never its provenance, so a
script can prove what a person proves. A stable per-participant feature vector
is itself a quasi-identifier — it would link the same actor across sessions,
which is exactly what L0 exists to prevent. And a behavioural signature used for
recognition is biometric data under EU law: it cannot be anonymised, because
recognition is its purpose. Admission is proved at L0 by the state identifier;
that a human sits behind a given session is not provable on-chain, here or
anywhere, and the architecture does not claim it.

### L1 → L2 Boundary

| Data | Direction | Format | Guarantee |
|------|-----------|--------|-----------|
| ZK identity proof | L1 → L2 | bytes (SNARK) | Valid registration |
| ZK nullifier | L1 → L2 | bytes32 | No double-vote |
| Encrypted choice | L1 → L2 | bytes (anti-collusion protocol) | Receipt-free inside the protocol perimeter |
| ZK correctness proof | L1 → L2 | bytes (SNARK) | Coordinator result valid |

**What does NOT cross:** Plaintext choice, participant address, intermediate choices.  
**Guarantee:** Receipt-freeness inside the protocol perimeter — a participant who holds their own key cannot produce a verifiable proof of their choice for a third party. Two premises lie outside that perimeter and are closed by no scheme in this architecture: someone watching the participant at the moment of choosing, and a key held by someone else. See "Receipt-Freeness Guarantee — and its limit" below.

### L2 → L4 Boundary (via L3)

| Data | Direction | Format | Guarantee |
|------|-----------|--------|-----------|
| VWU update counter | L2 → L4 | uint256 | Running total of applied updates — no address, no value, no delta |
| Per-commitment session delta | L2 → L4 | int256 against bytes32 | Signed contribution for one session, in the open, against the commitment it belongs to — see the third-channel note below |
| Session result | L2 → L4 | SessionResult struct | Coordinator-verified |
| Verdict proposed by the Harmony Agent | L2 → L4 | Verdict enum per side of the dilemma, with the cells and the scores it rests on | The agent's own conclusion, archived as submitted. The enum begins with the value for "no measurement was made"; green is a finding, never a default |
| Verdict recomputed by the chain | L2 → L4 | Verdict enum per side of the dilemma | Computed by `HarmonyAgent.computeFinalVerdict` from the submitted cells, by the map's own rule, and archived beside the agent's conclusion so that any divergence between the two stays visible to a reader. Not on the finalization path today: no contract calls that function, and `finalizeSession` stores the verdicts that arrive in the submitted result without comparing them with anything. What crosses this boundary as the session's verdict is therefore the agent's conclusion, and the recomputation is a separate record beside it. See `docs/AUTHORITY_CHAIN.md`, §14 |
| CellTriggered events | L2 → L4 | Event log | Immutable audit |
| Registration counter | L2 → L4 | uint256 | Running count of registered participants — no address, no commitment |

**What does NOT cross:** Individual choices, participant identities, VWU formula internals, individual support levels per dilemma, the moment at which a named participant changed status.  
A participant's VWU balance is not written across this boundary either, but it is no longer listed as withheld: it does not need to be written to be known. Every participant starts at the non-burnable base and every later change crosses as a per-commitment delta, so the balance held against any commitment follows by addition. Lens B4.  
**Guarantee:** Public verifiability without revealing individual choices.  
**Scope of this guarantee:** it covers the event log and the public API — the two channels that make bulk collection cheap. Solidity `private` is a compile-time visibility rule, not confidentiality: storage slots remain readable from an archive node. Plaintext-free storage of the balance is a Trial 2 design item, not a boundary this document can assert today.

**Third channel, and what was done about it (lens B5).** A boundary is crossed not only by events and getters but by the arguments of a call, which are visible on the peer-to-peer network before any block holds them and stay in the chain's history. Until 10.10.2026 the call that applies a session carried the inputs of the VWU calculation for each participant — completed steps, prompt flags, and the support level recorded for each of the three agenda dilemmas — against the commitment they belonged to. That is a per-person record of how someone responded, published after the reveal: the key rotation of L1 protects a choice up to that point and no further, and nothing in the line above held for it.

The calculation was moved out of the contract. The protocol computes each contribution and the call now carries one signed number per commitment. The per-session delta therefore still crosses this boundary, in the open, against a commitment — it is listed as crossing, not as withheld. What no longer crosses is the response it was computed from.

**What this costs, stated plainly.** With the formula outside the contract, a credit cannot be recomputed by a third party from on-chain data: correctness of a credit rests on the protocol today. A ZK proof of the credit closes this, and it belongs with plaintext-free storage of the balance — the same Trial 2 item, not a separate one. The guarantee of the counting itself is unaffected: the ZK correctness proof of the tally is independent of this change.

### L4 → L5 Boundary

This is the one boundary in this document where what crosses is not a number, a
hash or a proof, but text — and the text is written by participants.

| Data | Direction | Format | Guarantee |
|------|-----------|--------|-----------|
| Session records of a finalised session | L4 → L5 | archive read, aggregate | Read-only gateway; its schema contains no write endpoint |
| Proof records | L4 → L5 | archive read | Read-only gateway |
| VWU snapshot | L4 → L5 | aggregate | No individual choice is reachable through this channel |
| Dilemma text of the session | off-chain → L5 | text | None. The chain holds a commitment to the text, not the text |

**What does NOT cross:** individual choices, participant identities, the values the VWU calculation is composed of, and any write capability whatsoever.

**Guarantee:** an agent reads what the archive exposes and can change nothing. The orchestrating contract holds no write permission to L0–L4; the pre-built tool set is not declared on the agent, so no shell, file or network tool exists in its session; the gateway exposes read endpoints only.

**Scope of this guarantee:** it covers what an agent can *do*, not what an agent can be made to *say*. The text in the last row is authored by participants, and a language model draws no architectural line between an instruction and a datum — text placed there can steer what the agent reports. No current technique prevents this and the architecture does not claim to. Lens B1; the full position is in `docs/AUTHORITY_CHAIN.md`, §13.

### L5 → L2 Boundary

The agent layer writes to no data structure, but it does produce an output and that output crosses back. It is listed because a boundary document that omits it suggests the layer has no outward direction at all.

| Data | Direction | Format | Guarantee |
|------|-----------|--------|-----------|
| Observation signal | L5 → L2 | JSON signal, one per agent session | Required: validated against a fixed schema in ordinary code before submission. The contract cannot verify that this was done |
| Cells the Harmony Agent found touched | L5 → L2 | uint8 per matrix cell | Determined by the agent off-chain, outside the chain's view. Coordinates bounded to the 23 × 32 matrix and scores to 0–100 by the receiving contract; refused entries are counted and published |
| Counts of the result, per side of the dilemma | L5 → L2 | uint256 pairs | Submitted by the agent together with the cells, so that the chain can recompute on the same figures the agent read |
| The Harmony Agent's own conclusion | L5 → L2 | Verdict enum per side of the dilemma | Archived as submitted. It is not entered as the verdict: the chain recomputes and archives both |

**What does NOT cross:** any instruction, any write, any influence on a participant's weight, any access to an individual choice.

**Guarantee:** the contract aggregates the signals by a fixed rule no agent can change, and refuses malformed entries before aggregation rather than skipping them silently. For the verdict the rule is stricter than aggregation: `HarmonyAgent.computeFinalVerdict` recomputes it from the submitted cells by the map's own rule and archives its own result beside the agent's conclusion, so that the two can be read against each other.

**What is not wired, and bounds the line above.** No contract of the package calls that function. `BeTrueCoreCore` holds a pointer to the agent contract and never uses it: `finalizeSession` stores the two verdicts that arrive in the submitted result and compares them with nothing. The recomputation therefore stands beside the path a session takes rather than on it, and a coordinator may recompute one verdict and finalize another with no check noticing. Until finalization takes its verdicts from that computation, or refuses a result that disagrees with it, this is a function that is available and not a guarantee that is enforced. It is recorded as `not established on the finalization path` in the requirements table of `docs/AUTHORITY_CHAIN.md`, §14.

**Scope of this guarantee:** the arithmetic is exact over inputs that are testimony. The cells themselves are testimony too — which cells a result touches is determined by the agent, off-chain, and the chain recomputes from what it was given rather than finding the cells itself. A signal from L5 carries the standing of a witness statement, not of a measurement, and no text of this project should present it otherwise.

| Agent | Reads from | Writes to | Function |
|-------|-----------|-----------|----------|
| Analyst × 3 | L4 archive — commitments and proof records | NOTHING | Signal verification |
| Strategist × 3 | L4 archive — session results and audit log | NOTHING | Ethical signal, risk signal, and the Harmony Agent's verdict proposal |
| Sentinel × 3 | L4 archive — records of all layers as archived | NOTHING | Security monitoring |

**Constitutional principle:** AI agents have NO write access to any data structure. The principle holds for the register and not for the testimony: no mechanism lets an agent write the author's verdict, and none constrains what the agent says it saw.  
**"AI is the notary. The human is the author."**

---

## Anti-Collusion Protocol Integration Points

### Key Rotation Protocol

```
Session open
    ↓
Participant submits encrypted choice
    ↓
Participant may rotate key + submit new choice (up to the per-participant
message limit; once spent, it is spent for the rest of the session)
    ↓
TIME LOCK — session closes
    ↓
Only FINAL choice counts (previous keys invalidated)
    ↓
Coordinator publishes result + ZK correctness proof
    ↓
Coordinator cannot falsify — fraudulent proof rejected by verifiers
```

### Receipt-Freeness Guarantee — and its limit

Inside the protocol perimeter, a participant cannot demonstrate their final choice to any external party, because:
1. All intermediate choices are equally plausible
2. Final choice is cryptographically hidden until after time lock
3. Key-rotation invalidates all intermediate proofs

Two premises lie outside that perimeter and are closed by no scheme here: someone watching the participant at the moment of choosing, and a coercer holding the message key, who then sends the last message himself and is served by key rotation exactly as the participant would be. Re-choice is bounded as well, by the per-participant message limit named above. The full statement is in `docs/AUTHORITY_CHAIN.md`, §12, and in `WHITEPAPER.md`, 5.7.

### The Coordinator Role — a boundary of its own

The coordinator named in the tables above is a role held by an address, as are the address that writes the Merkle root and the address registered as the Harmony Agent in the matrix contract. The roles are named here rather than left implicit, because a boundary document that omits them describes a protocol with no holders.

**What holds.** A role is transferred in two steps and never in one: the current holder nominates, the nominee accepts, and nothing has moved until acceptance. Both steps emit events, so a change of hands is archived rather than silent. No role reads an individual choice, alters a record already written, or changes a participant's weight, and the bounds a contract places on the values it accepts hold against the role as against anyone else.

**What does not hold, and is not claimed.** That a role belongs to the community cannot be proved while an address holds it. It is disclosed, not proved: who holds the key is named publicly, and a reader is relied upon to look. No statute closes this — a community has no legal personality and needs none, and the statutes of the association that operates the application are the association's, not the community's. Resting the claim on those statutes would cut the root of authority this architecture starts from: the root of a mandate is the decision procedure itself, not a register entry.

**How it becomes proved.** By the role disappearing. By the third trial the community governs through the protocol itself and there is nothing left for anyone to hold. The full statement is in `docs/AUTHORITY_CHAIN.md`, §14.

---

## VWU Calculation Boundary

The VWU formula has a defined disclosure boundary: what it is composed of is
public, the coefficients are not, and — since 10.10.2026 — the values it is
computed from do not leave the protocol.

**Where the calculation runs.** In the protocol, before the session is applied
to L2. The contract receives the computed contribution, bounds it against the
non-burnable base and the cap, and credits it. It does not receive the values
below and cannot reconstruct them.

**What the calculation is composed of (public as a list, private as values):**
- `steps_completed` (uint8, 0–7) — depth of the seven-step participation cycle
- `prompt_submitted` (bool) — whether the participant submitted a prompt
- `prompt_in_agenda` (bool) — whether that prompt entered the TOP-3 agenda
- `dilemma_support` (uint8[3]) — support level recorded for each of the three
  agenda dilemmas, which are the same three for everyone; the value is the
  individual participant's, and the scale itself is protected

These four are named here so that the composition of the measure is open to
inspection. Their values are a per-person record of how someone responded, and
they are not published anywhere: not in an event, not in a getter, and not in
the arguments of a call. See the note on the third channel under the L2 → L4
boundary above.

**Output (public):**
- `vwu_delta` (int256) — signed change to the participant's VWU balance;
  the balance never falls below the non-burnable base of 1.00 VWU, stored as
  100 at the ×100 scale used throughout the engine
**Internal mechanics (protected):**
- Non-linear growth factor
- Component limits and the support-level scale
- Memory length and adaptation coefficients
- Full formula specification

**Open part of the composition:** Activity 40% + Utility 60%.

The Harmony Agent traffic-light verdict is not part of this calculation. It is
an ethical indication displayed by the Panorama, applied to each side of a
dilemma separately — Option A and Option B alike, by one and the same measure —
while silence receives no colour at all. It does not affect participant weight.

**Protection:** BeTrueCore master document, timestamped via OpenTimestamps SHA-256.

---

## External System Boundaries

### ReceiptOS Integration (Mapping v0)

| Interface point | BeTrueCore provides | ReceiptOS provides |
|----------------|--------------------|--------------------|
| Session result | Aggregated VWU-weighted outcome | Receipt verification |
| ZK proof | Correctness proof of counting | Audit confirmation |
| Celestia DA | Public log reference | Independent audit |

### Celestia DA Public Audit

All events written to Celestia DA are:
- **Immutable** — cannot be altered after writing
- **Public** — any independent observer can verify
- **Trustless** — no need to trust BeTrueCore backend

Events logged, in the form they take after the public-surface audit of
04.10.2026 — none of them names a participant:

| Event | Carries |
|-------|---------|
| `RegistryGrew` | running count of registered participants |
| `ChoiceRecorded` | session id only |
| `ParticipationApplied` | session id, number of records applied |
| `SessionFinalized` | session id; six values — a count and the sum of the weight behind it for OPTION_A, for OPTION_B and for silence; the tally proof hash; and two verdicts, one per option, each recorded both as the Harmony Agent submitted it and as the chain recomputed it |
| `CellTriggered` | session id, matrix cell, Ematch score, verdict |
| `VerdictComputed` | session id, aggregate score, verdict, cells activated |
| `VWUUpdated` | running count of updates — no address, no value |
| `StatusAdvanced` | status level and how many participants hold it |
| `PollOpened`, `ParticipantJoined`, `MessagePublished`, `PollFinalized` | poll id, session-bound nullifier, encrypted payloads, aggregated totals |

**Legal status of what is archived.** Most of the twelve events carry nothing bound to a participant: session ids, matrix cells, Ematch scores, verdicts, aggregated results. Four need care. `ParticipantJoined` carries a session-bound nullifier — it names nobody, but within one session it distinguishes one participant from the rest, and that is what a pseudonym does; under EU data protection law a pseudonym is an identifier, not the absence of one. `RegistryGrew` and `StatusAdvanced` carry counts over the community, and the assessment once deferred was made by the lens B4 audit of 14.10.2026: each is published on every event that moves it, so what the log holds is a numbered notice rather than an aggregate — consecutive values differ by one participant, and the transaction that caused the move stands beside them. `SessionFinalized` is the widest of the four, and its width is a decision rather than a leak: six values go out, and the roster total the Panorama shows at its head is the sum of the three, by people and by weight alike, so the chain stores six values and no seventh; and because silence covers those who did not take part at all as well as those who chose nothing, the three rows account for the whole roster exactly. So the three-way split of a session is not something an arithmetician reconstructs; it is something the protocol states. Note what the event does not carry: which side was the majority. The chain records OPTION_A and OPTION_B, never which of them was larger, and reading the numbers is what makes one of them the majority — so a verdict can never have been issued on the strength of that. What is protected is not the figures but which participant stands behind which value, and that is the work of L0 and L1. The weight sums carry further than the counts, because weight is individual and changes slowly: in a small and stable community a sum over a series of sessions is a narrower fact than a count, and that series is the part not yet assessed.

Because the archive is immutable by design, a record written here cannot be removed afterwards. The architecture answers this by not writing what would have to be removed: no address, no balance, no delta, no participant-bound value beyond the session-scoped nullifier. The published guidance on anonymisation does not address immutable public ledgers at all, so nothing in this paragraph rests on it. The full data-protection position, with its sources, is in `docs/AUTHORITY_CHAIN.md`, §11.

---

## Glossary

| Term | Definition |
|------|-----------|
| Receipt-freeness | Property that prevents a participant who holds their own key from proving their choice to a third party, inside the protocol perimeter. It does not hold against observation at the moment of choosing, nor against a key held by someone else |
| Time lock | Session close — after which no choice changes are accepted |
| ZK nullifier | Cryptographic token preventing double-voting |
| VWU | Vote Weight Unit — non-transferable, non-marketable participation weight |
| Anti-collusion protocol | Circom/Groth16 implementation of the MACI pattern for collusion-resistant voting. The MACI repository (appliedzkp/maci) was archived August 19, 2026. BeTrueCore builds independently on the Groth16 proving system and the Circom toolchain, and depends on no MACI release or version |
| Ematch | Ethical match score (0–1) for each intersection cell in the 736-point matrix |