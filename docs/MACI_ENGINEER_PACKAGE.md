# BeTrueCore Anti-Collusion Engineer Package
## Circom/Groth16 Anti-Collusion Protocol — Integration Guide

**Version:** 0.1  

**Repository:** github.com/Dede-Qorqud/BeTrueCore  
**Cryptographic standard:** Circom/Groth16 (MACI anti-collusion pattern)

> *Note: The MACI repository (appliedzkp/maci) was archived August 19, 2026. BeTrueCore builds on the Circom/Groth16 cryptographic standard implementing the MACI anti-collusion pattern.*

---

## Overview

This package describes how BeTrueCore implements the MACI anti-collusion pattern on the Circom/Groth16 cryptographic standard as the foundation for collusion-resistant collective decision-making. The protocol provides receipt-freeness, key-rotation, and ZK correctness proofs.

**Core property:** A participant can change their binary choice multiple times until the time lock. Only the final choice counts. No intermediate choice can serve as proof of a transaction — because all are equally plausible.

---

## Architecture Integration

```
BeTrueCore L1 Layer
├── Anti-Collusion Protocol (Circom/Groth16)
│   ├── MessageProcessor.sol    — processes encrypted messages (key rotations + votes)
│   ├── Poll.sol                — manages active session (dilemma + time window)
│   ├── Tally.sol               — aggregates final results with ZK proof
│   └── Verifier.sol            — verifies ZK correctness proofs on-chain
├── Lit Protocol MPC            — threshold key management for coordinator
└── ZK Nullifier Registry       — prevents double-voting across sessions
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
2. Tally final choices weighted by VWU
3. Generate ZK correctness proof (Groth16)
4. Publish result + proof on-chain
        ↓
BeTrueCoreCore.finalizeSession(session_id, result)
        ↓
HarmonyAgent computes ethical verdict (736-point matrix)
        ↓
All events logged to Celestia DA
```

---

## Black Box: VWU Calculation

The VWU formula is intentionally opaque at the protocol boundary.

**Coordinator provides to VWUEngine:**
```solidity
struct SessionResult {
    address participant;        // derived from ZK identity commitment
    uint8   activity_score;    // 0–100: did participant complete all 7 actions?
    bool    aligned_majority;  // did final choice match weighted majority?
    uint256 session_timestamp;
}
```

**VWUEngine returns:** `vwu_delta` (uint256)

**What the coordinator does NOT see:** VWU formula internals, non-linear growth factor, continuity adjustment mechanics.

---

## ZK Circuit Requirements

### Identity Circuit (Circom)
```
Inputs (private):
  - fin_commitment (from L0 FIN-code ZK-transformation)
  - behavioral_entropy (VWU behavioral record — see Preprint 11)

Inputs (public):
  - identity_commitment (bytes32)

Output:
  - valid_registration (bool)

Constraint: fin_commitment + entropy → identity_commitment
```

### Vote Proof Circuit (Circom)
```
Inputs (private):
  - participant_key (participant's current key)
  - choice (OPTION_A or OPTION_B)
  - nullifier_secret

Inputs (public):
  - nullifier_hash (bytes32)
  - session_id (uint256)

Output:
  - encrypted_message (for MessageProcessor)

Constraint: nullifier has not been used, key is valid for session
```

### Tally Proof Circuit (Groth16)
```
Proves: the published tally correctly aggregates all final choices
        without revealing any individual choice
Used by: Verifier.sol (on-chain verification)
```

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

---

## Sybil Resistance

Three independent layers (must all be bypassed simultaneously):

| Layer | Mechanism | What attacker needs |
|-------|-----------|---------------------|
| L0 | FIN-code ZK-commitment + MPC key split | State-registered identity on verified device |
| L1 | ZK nullifier chain | Unique cryptographic identity per device |
| L5 | Sentinel agent pattern detection | Behavioral diversity across hundreds of sessions |

---

## Anti-Vote-Buying Properties

Vote buying fails at two levels:

**No verifiable commodity:**  
Participant can show any intermediate choice as "proof" of voting for buyer.  
All intermediate choices are cryptographically equally valid.  
Final choice is hidden until time lock — buyer cannot verify.

**No currency:**  
VWU is non-transferable and non-marketable.  
VWU cannot be sold — it is not alienable.  
There is no accepted currency for the transaction.

---

## Engineer Notes

### Anti-Collusion Protocol Parameters

```typescript
// Recommended session configuration
const pollDuration = 3600;        // 1 hour time window
const maxMessages = 25000;        // max choices per session
const maxVoteOptions = 2;         // binary choice only (OPTION_A / OPTION_B)
const intStateTreeDepth = 10;
const messageTreeDepth = 20;
const voteOptionTreeDepth = 2;
```

### Deployment Checklist

- [ ] Deploy anti-collusion contracts (PollFactory, MessageProcessorFactory, TallyFactory)
- [ ] Configure Lit Protocol MPC for coordinator key
- [ ] Deploy ZK verifier contracts (Groth16)
- [ ] Deploy BeTrueCoreCore with coordinator address
- [ ] Deploy EthicalMatrix and populate 736 cells
- [ ] Deploy HarmonyAgent connected to EthicalMatrix
- [ ] Deploy VWUEngine connected to coordinator
- [ ] Configure Celestia DA indexer for event logging
- [ ] Run Foundry tests (see BeTrueCore.t.sol)

### Known Constraints

1. **Coordinator availability:** The coordinator must be online to process sessions. Lit Protocol MPC mitigates single point of failure but does not eliminate availability risk.

2. **ZK proof generation time:** Tally proof generation takes 2–10 minutes depending on session size. Plan coordinator infrastructure accordingly.

3. **Gas costs:** Each message costs ~50k gas on L2. For 100 participants × 3 choice changes = 15M gas per session. Optimism L2 makes this feasible.

4. **Nullifier storage:** ZK nullifiers accumulate over time. Plan for nullifier registry pruning strategy after MVP phase.
