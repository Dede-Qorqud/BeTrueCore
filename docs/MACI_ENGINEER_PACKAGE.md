# BeTrueCore Anti-Collusion Engineer Package
## Circom/Groth16 Anti-Collusion Protocol — Integration Guide

**Version:** 0.3  

**Repository:** github.com/Dede-Qorqud/BeTrueCore  
**Proving system and toolchain:** Groth16 over BN254, circuits in Circom (MACI anti-collusion pattern)

> *Note: The MACI repository (appliedzkp/maci) was archived August 19, 2026. BeTrueCore builds independently on the Groth16 proving system and the Circom toolchain, implementing the MACI anti-collusion pattern, and depends on no MACI release or version.*

---

## Overview

This package describes how BeTrueCore implements the MACI anti-collusion pattern on the Groth16 proving system as the foundation for collusion-resistant collective decision-making. The protocol provides key rotation, ZK correctness proofs, and receipt-freeness inside the protocol perimeter — bounded as stated below.

**Core property:** A participant can change their binary choice up to the per-participant message limit, until the time lock. Only the final choice counts. No intermediate choice can serve as evidence of how the participant chose — because all are equally plausible.

**The bound on that property, stated here and not further down.** It holds for a participant who holds their own key. It does not hold against someone watching the participant at the moment of choosing, and it does not hold against someone who holds the message key: that person sends the last message himself, and key rotation serves him exactly as it would serve the participant. Neither premise is closed by any scheme in this package. The election literature closes the second with a fake key indistinguishable from a real one (Juels, Catalano and Jakobsson); no such primitive is built here. The full statement is in `docs/AUTHORITY_CHAIN.md`, §12, and in `WHITEPAPER.md`, 5.7.

---

## Architecture Integration

```
BeTrueCore L1 Layer
├── Anti-Collusion Protocol (Circom/Groth16)
│   ├── MessageProcessor.sol    — processes encrypted messages (key rotations + votes) [NOT WRITTEN]
│   ├── Poll.sol                — manages active session (dilemma + time window) [written]
│   ├── Tally.sol               — aggregates final results with ZK proof [NOT WRITTEN]
│   └── Verifier.sol            — verifies ZK correctness proofs on-chain [NOT WRITTEN]
├── Lit Protocol MPC            — threshold key management for coordinator [Phase 2]
└── ZK Nullifier Registry       — prevents double-voting across sessions
                                  (contracts/NINNullifierRegistry.sol) [written]
```

---

## Session Lifecycle

### Phase 1: Session Open

```solidity
// BeTrueCoreCore.sol calls:
uint256 session_id = openSession(dilemma_hash, duration_seconds);

// Poll.sol is deployed simultaneously:
// Poll.sol tracks: startTime, endTime, maxValues, treeDepths
```

### Phase 2: Choice Submission (during time window)

```
Participant → submitChoice(session_id, encrypted_choice, zk_nullifier)
                ↓
         MessageProcessor
                ↓
         Encrypted message stored in message tree
         (choice hidden until coordinator processes)
```

**Key rotation flow:**
```
Choice 1 (T=0):    Participant submits EncMsg(key_1, OPTION_A)
Choice 2 (T=30):   Participant rotates key: EncMsg(key_2, OPTION_B)
Choice 3 (T=45):   Participant rotates key: EncMsg(key_3, OPTION_A)
TIME LOCK (T=60):  Only Choice 3 (OPTION_A via key_3) is valid
                   Choices 1 and 2 are cryptographically invalidated
```

### Phase 3: Finalization (after time lock)

```
Anti-Collusion Coordinator (Lit Protocol MPC quorum)
        ↓
1. Process all messages (decrypt with coordinator key)
2. Tally final choices weighted by VWU — six values, not two:
   a count and the sum of the weight behind it for OPTION_A,
   for OPTION_B and for silence. Silence covers those who took
   part without choosing AND those who did not take part at all,
   so it is the fixed roster less the two sides — it cannot be
   summed from submitted messages alone. The roster total the
   Panorama shows is the sum of the three; store six, not seven.
   Do not pass which side is the majority: the chain must not know it
3. Generate ZK correctness proof (Groth16)
4. Publish result + proof on-chain
        ↓
BeTrueCoreCore.finalizeSession(session_id, result)
   the two verdicts carried in `result` become the session's verdicts,
   compared with nothing — see the note below this diagram
        ↓
Harmony Agent (one of the nine L5 agents) determines off-chain which
cells of the 736-point map the outcome touches, applies the map to each
side of the dilemma separately, and submits the cells, their scores, the
counts of the result and its own conclusion — one conclusion per side,
none for silence
        ↓
HarmonyAgent.computeFinalVerdict recomputes the verdict from the submitted
cells by the map's own rule. Both are archived side by side — the agent's
conclusion and the chain's recomputation — so that any divergence stays
visible to a reader. The verdict enum begins with the value for "no
measurement was made"; green is a finding, never a default
        ↓
BeTrueCoreCore.applySessionParticipation(...)
   per-participant contribution submitted separately from the tally
        ↓
All events logged to Celestia DA
```

**Read the two middle steps apart.** The recomputation above is a step the
package can perform and not a step it performs: `computeFinalVerdict` is called
by no contract. `BeTrueCoreCore` holds a pointer to the orchestrating contract
and never uses it, and `finalizeSession` stores the verdicts out of the
submitted result without comparison. So in the flow as deployed, the verdict a
session carries is the agent's conclusion, and the recomputation — if a
coordinator runs it at all — leaves a separate record beside the session rather
than a check upon it. An engineer wiring this is wiring two independent calls,
not one chain. Until finalization draws its verdicts from that computation, or
refuses a result that disagrees with it, the requirements table of
`docs/AUTHORITY_CHAIN.md`, §14, carries this as `not established on the
finalization path`.

---

## Disclosure Boundary: VWU Calculation

The VWU formula has a defined disclosure boundary: the inputs and the
composition weights are public, the coefficients are not.

**Where the calculation runs.** In the protocol, before the session is applied on-chain. This changed on 10.10.2026 and the change is the point of this section: the contract receives a computed contribution, bounds it against the non-burnable base and the cap, and credits it. It does not receive the values the contribution was computed from, and cannot reconstruct them.

**What crosses the call to VWUEngine:** one signed contribution per commitment — the identity commitment it belongs to, the signed delta, and the session timestamp. Nothing else. Build nothing that passes more: the arguments of a call are visible on the peer-to-peer network before any block holds them and remain in the chain's history, so a per-person record of how someone responded, passed here, would be published after the reveal. Key rotation at L1 protects a choice up to the time lock and no further. See the third-channel note under the L2 → L4 boundary in `docs/MAPPING_MODEL.md`.

struct SessionResult {
    address participant;
    int256  delta;              // the computed contribution, VWU units ×100,
                                // signed: the rational filter yields a negative
    uint256 session_timestamp;
}

Note the name: three different structs in this package are called `SessionResult` — the tally of a session in `IBeTrueCore.sol`, one participant's contribution here, and the poll result at L1. The code tells them apart by their contract; a reader has to be told.

**What the contribution is computed from (public as a list, never as values):** depth of the seven-step cycle (0–7); whether a prompt was submitted; whether that prompt entered the TOP-3 agenda; the support level recorded for each of the three agenda dilemmas. These four are named so that the composition of the measure is open to inspection. Their values appear in no event, no getter, and no call argument.

**VWUEngine returns:** `delta_applied` (int256) — the delta applied to this participant's rating in this session. Accumulated balances are readable by no one on-chain: the personal getters were removed from `VWUEngine.sol`, because the record is keyed by an address derived from the commitment and nobody holds the private key to that address. A participant sees their own colours and points in the application; on-chain personal reading returns later, served by a proof of ownership rather than by the caller's address.

**Composition (public):** Activity 40% + Utility 60%.

**What the coordinator does NOT see:** VWU formula internals, component limits, the support-level scale, memory and adaptation coefficients, the non-linear growth factor.

**What this costs, stated plainly.** With the formula outside the contract, a third party cannot recompute a credit from on-chain data: correctness of a credit rests on the protocol today. A ZK proof of the credit closes this, together with plaintext-free storage of the balance — one item, not two. The guarantee of the counting itself is unaffected: the ZK correctness proof of the tally is independent of this change.

The Harmony Agent traffic-light verdict is not an input to this computation. It is an ethical indication displayed by the Panorama, applied to each side of a dilemma separately — OPTION_A and OPTION_B alike, by one and the same measure — while silence receives no colour at all. It does not affect participant weight.

---

## ZK Circuit Requirements

### Registration Circuit — `circuits/NINCommitment.circom`

Inputs (private):

nin_preimage (NIN encoded as a BN254 field element, client-side)
registration_salt (254-bit random, generated once at registration)
identity_secret (254-bit random, held by the participant)

Inputs (public):

none

Output (public):

identity_commitment

Constraints:
nin_key = Poseidon(nin_preimage, registration_salt)
identity_commitment = Poseidon(nin_key, identity_secret)

What this circuit does NOT prove — state it this way wherever it is described.
The circuit proves knowledge of three field elements whose two-layer Poseidon
hash is this commitment: a proof of knowledge of a preimage, nothing more. It
does not prove that nin_preimage is a real National Identification Number, that
the number was confirmed by the e-government gateway, or that one citizen holds
one leaf. No signal in this circuit comes from outside the prover's device, so
any three field elements produce a valid proof. Gateway verification exists at
L0 but runs in the client, and nothing cryptographic ties "the gateway confirmed
this number" to "this leaf". Binding it inside the circuit would require an
attestation signed by the gateway as a private input, with the gateway's public
key as a public input — that is unbuilt work, not an existing property.

Also note: in the current construction this proof has no verifier. No contract
checks it; the tree root is written by a single address and the leaves are
computed off-chain.


No behavioural input exists. An earlier design verified the participant
biometrically; that channel was withdrawn when the project moved to the
NIN-code, and nothing in the circuits reads behaviour. See the withdrawal note
in `docs/MAPPING_MODEL.md` for the reasons.

### Session Circuit — `circuits/NINIdentityProof.circom`

Inputs (private):

nin_preimage, registration_salt, identity_secret
path_elements[LEVELS], path_indices[LEVELS] (Merkle path)

Inputs (public):

merkle_root (current root of the registered-participant tree)
external_nullifier (session id, supplied by Poll.sol)

Output (public):

nullifier = Poseidon(identity_secret, external_nullifier)

Constraints — five, all enforced simultaneously:
1. nin_key = Poseidon(nin_preimage, registration_salt)
2. identity_commitment = Poseidon(nin_key, identity_secret)
3. identity_commitment is a leaf under merkle_root
4. nullifier = Poseidon(identity_secret, external_nullifier)
5. every path_indices[i] is 0 or 1 — enforced inside lib/BinaryMerkleTree.circom,
   not in this circuit. Without it (3) does not hold: the multiplexers are
   linear in that selector, so a non-binary value would let a prover steer the
   computed root.

The leaf is NOT an input: it is recomputed by (1) and (2), which is why
membership cannot be claimed for the filler values of the tree's empty slots.

Public signal order, as circom lays it out and snarkjs keeps it — outputs
first, then public inputs in the order they are declared. Read off the source
of `circuits/NINIdentityProof.circom`, which declares one output, `nullifier`,
and two public inputs, `merkle_root` then `external_nullifier`: [0] nullifier,
[1] merkle_root, [2] external_nullifier. The circuits have not been compiled
yet, so this order rests on the language rule and the source, not on a symbol
file; confirm it against the generated `.sym` before a verifier is wired to it.
Any contract or script that passes them in another order verifies a different
statement and rejects every honest proof.

What this circuit enforces about uniqueness is one entry per SECRET, not one
per citizen: two leaves with two different secrets yield two nullifiers in one
session, and nothing binds a citizen to a single live leaf.


The choice is not an input to this circuit and is not encrypted by it. The
circuit proves membership and derives a session-bound nullifier; encryption of
the choice happens on the participant's device, and `Poll.sol` carries the
ciphertext. Nullifier freshness is checked on-chain, not in the circuit.

### Tally Proof Circuit (Groth16)
```
Proves: the published tally correctly aggregates all final choices
        without revealing any individual choice
Used by: Verifier.sol (on-chain verification)
```

**Requirement 1 — the tally commitment must be blinded.** The hash published as
the commitment to the counted choices must be taken over the counted choices
TOGETHER WITH a random blinding value, which the coordinator keeps and reveals
only if the result is disputed. An unblinded hash hides only what cannot be
guessed, and here almost nothing needs guessing: the Panorama publishes the
roster total at its head, and three counts with three weight sums beneath it,
so in a small community the possible splits can be enumerated, hashed, and
compared against the published value. An unblinded commitment stops being a
seal and becomes an oracle that confirms a guess. The blinding value must be a
PRIVATE input of this circuit — if the commitment is passed as a public input,
a blinding value passed publicly alongside it would be revealed by the proof
itself.

**Requirement 2 — a message must be bound to its state leaf before it can be
marked invalid.** This is a known under-constrained circuit, not a theoretical
worry: in MACI 1.0 the coordinator ordered the state leaves, so a message could
be applied to someone else's public key, be marked invalid for not matching,
and never reach the check that would have caught the mismatch — the coordinator
could censor any chosen response and still produce a passing proof. The fix was
one constraint, binding each message to the index it claims before any
invalidity test runs. BeTrueCore does not inherit that fix: the MACI repository
was archived on 19.08.2026 and this project builds its own circuits on the same
pattern. Whoever writes the message-processing circuit must carry the
constraint, and a reviewer must look for it by name. Censorship of a response
by the coordinator defeats completeness of the set, which is the property this
protocol exists to defend.

---

## Coordinator Security Model

The coordinator is protected by Lit Protocol threshold MPC:

```
Coordinator key = distributed across N Lit Protocol nodes
Threshold: k-of-N nodes must agree to decrypt (k < N)

Attack scenario: Coordinator captured
Result: Coordinator can DENY SERVICE (withhold result)
        Coordinator CANNOT FALSIFY result
        (fraudulent ZK proof rejected by on-chain Verifier.sol)

Attack converts: integrity attack → availability attack
```

**Who holds the role.** The threshold scheme above bounds what a captured coordinator can do. It says nothing about who the coordinator is, and that question is answered separately. The coordinator is a role held by an address, as are the address that writes the Merkle root and the address registered as the Harmony Agent in the matrix contract.

Transfer runs in two steps and never in one: the current holder nominates, the nominee accepts, and nothing has moved until acceptance. Both steps emit events, so a change of hands is archived rather than silent.

That the role belongs to the community cannot be proved while an address holds it. It is disclosed, not proved: who holds the key is named publicly, and a reader is relied upon to look. No statute closes this — a community has no legal personality and needs none, and the statutes of the association that operates the application are the association's, not the community's. Resting the claim on those statutes would cut the root of authority this architecture starts from: the root of a mandate is the decision procedure itself, not a register entry. The role becomes proved by disappearing: by the third trial the community governs through the protocol itself and there is nothing left for anyone to hold. The full statement is in `docs/AUTHORITY_CHAIN.md`, §14.

---

## Sybil Resistance

Sybil resistance in this architecture is not three independent cryptographic layers. It rests on one organisational guarantee, and the table says which:

| Layer | Mechanism | What an extra entry costs |
|-------|-----------|---------------------------|
| L0 | NIN-code checked at the e-government gateway — in the client, not on-chain | A leaf in the registered tree. Registration verifies no proof on-chain and restricts no caller, so an extra leaf costs one call: no work, no stake, no vouch, no ceremony. The tree is assembled off-chain and only its root reaches the contract, which cannot tell a root carrying the commitments of those who registered from one carrying a leaf nobody chose |
| L1 | ZK nullifier chain | A secret behind one leaf. What this enforces is one entry per SECRET, not one per citizen: two leaves with two secrets yield two nullifiers in one session |
| L5 | — | Nothing. Sybil identification is not a function of this layer: an extra participant leaves no aggregate for an agent to read, and no agent decides anything in any case |

**Where the guarantee actually sits.** With the identifier checked in the client, the substrate of this resistance is a state register record rather than a test distinguishing a human from a machine — forging it means forging the register, not passing a test, and cheaper imitation of a human does not move this boundary. It is an organisational guarantee and is named as one wherever this project claims it. The cryptographic part that is missing is named too: a third-party-verifiable proof that a root transition inserted exactly the announced commitments and nothing else. It is the `not established` row of the requirements table, and it is the one place where outside specialist work is needed.

---

## Anti-Vote-Buying Properties

Buying a *stated* choice is pointless. Buying the *key* is not, and the difference is the whole of this section.

**No verifiable commodity:**  
A participant can show any intermediate choice as "proof" of how they voted.  
All intermediate choices are cryptographically equally valid.  
The final choice is hidden until the time lock — a buyer cannot verify it.  
So a seller can state one thing and silently override it afterwards, and the buyer has bought nothing.

**Nothing inside the protocol to pay with:**  
VWU is non-transferable and non-marketable, and cannot be sold — it is not alienable.  
There is no unit inside the protocol in which such a bargain could be settled. Payment outside the protocol is of course not prevented by this.

**What this does not reach, stated rather than left out:**  
A buyer who obtains the message key does not need the seller's word: he sends the last message himself, and key rotation serves him exactly as it would serve the participant.  
Entry is visible even where the choice is not — a transaction is sent from the participant's own address, so a demand to abstain is checkable by looking.  
Re-choice is bounded by the per-participant message limit; once spent within a session, it is spent for the rest of it.  
The shape of the claim: whoever can punish everyone needs to identify no one. The protocol does not make vote buying or coercion fail — it removes the evidence a buyer would need to tell compliance from defection inside the perimeter (`WHITEPAPER.md` 5.7, `docs/AUTHORITY_CHAIN.md` §12).

---

## Engineer Notes

### Anti-Collusion Protocol Parameters

```typescript
// Recommended session configuration
const pollDuration = 3600;        // 1 hour time window
const maxMessages = 20;           // max messages PER PARTICIPANT per session
const maxVoteOptions = 2;         // binary choice only (OPTION_A / OPTION_B)
const intStateTreeDepth = 10;
const messageTreeDepth = 20;
const voteOptionTreeDepth = 2;
```

### Deployment Checklist

- [ ] Deploy anti-collusion contracts (PollFactory, MessageProcessorFactory, TallyFactory)
- [ ] Configure Lit Protocol MPC for coordinator key
- [ ] Deploy ZK verifier contracts (Groth16)
- [ ] Deploy NINNullifierRegistry with the verifier address and the initial Merkle root
- [ ] Point the registry at Poll.sol (setPoll) — until this is done, verifyAndRegister reverts with OnlyPoll and nobody can enter a session
- [ ] After each registration batch, write the new root into the registry (updateMerkleRoot) — a proof is valid only against the root the registry holds at that moment, so registration stays frozen for the duration of a session
- [ ] Carry that freeze through to the participant: someone who registers while a session is open is registered and joins from the next session, and the application tells them so at that moment — admission is confirmed when the current session ends. The contract side of this is the roster fixed by openSession (`src/IBeTrueCore.sol`, Session); do not let a late registrant be counted into a session whose roster was already taken
- [ ] Deploy BeTrueCoreCore with coordinator address
- [ ] Deploy EthicalMatrix and populate 736 cells
- [ ] Deploy HarmonyAgent connected to EthicalMatrix, then register it in EthicalMatrix (setHarmonyAgent)
- [ ] Set the coordinator in HarmonyAgent (setCoordinator) — without it no verdict can be issued
- [ ] Deploy VWUEngine, then set BeTrueCoreCore as its coordinator (setCoordinator)
- [ ] NOTE ON EVERY ROLE ASSIGNMENT ABOVE: each one is two steps, not one. The current holder nominates, the nominee accepts, and the role has not moved until acceptance — a deployment that stops after the nomination leaves the contract without a holder and the next step reverting. Both steps emit events; check the events rather than the storage slot
- [ ] Configure Celestia DA indexer for event logging
- [ ] Run Foundry tests (see BeTrueCore.t.sol)

### Known Constraints

1. **Coordinator availability:** The coordinator must be online to process sessions. Lit Protocol MPC mitigates single point of failure but does not eliminate availability risk.

2. **ZK proof generation time:** Tally proof generation takes 2–10 minutes depending on session size. Plan coordinator infrastructure accordingly.

3. **Gas costs:** Each message costs ~50k gas on L2. For 100 participants × 3 choice changes = 15M gas per session. Optimism L2 makes this feasible.

4. **Nullifier storage:** ZK nullifiers accumulate over time. Plan for nullifier registry pruning strategy after MVP phase.