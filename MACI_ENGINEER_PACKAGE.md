# BeTrueCore MACI Engineer Package
## Minimal Anti-Collusion Infrastructure — Integration Guide

**Version:** 0.1  
**Author:** Farman Guliyev (Safarnur)  
**Repository:** github.com/Dede-Qorqud/BeTrueCore  
**MACI Reference:** appliedzkp/maci v1.2

---

## Overview

This package describes how BeTrueCore integrates MACI v1.2 as the cryptographic foundation for collusion-resistant collective decision-making. MACI provides receipt-freeness, key-rotation, and ZK correctness proofs.

**Core property:** A participant can change their binary choice multiple times until the time lock. Only the final choice counts. No intermediate choice can serve as proof of a transaction — because all are equally plausible.

---

## Architecture Integration

```
BeTrueCore L1 Layer
├── MACI v1.2
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

// MACI Poll is deployed simultaneously:
// Poll.sol tracks: startTime, endTime, maxValues, treeDepths
```

### Phase 2: Choice Submission (during time window)

```
Participant → submitChoice(session_id, encrypted_choice, zk_nullifier)
                ↓
         MACI MessageProcessor
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
MACI Coordinator (Lit Protocol MPC quorum)
        ↓
1. Process all messages (decrypt with coordinator key)
2. Tally final choices weighted by VWU
3. Generate ZK correctness proof (Groth16 / PLONK)
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

The VWU formula is intentionally opaque at the MACI boundary.

**MACI provides to VWUEngine:**
```solidity
struct SessionResult {
    address participant;        // derived from ZK identity commitment
    uint8   activity_score;    // 0–100: did participant complete all 7 actions?
    bool    aligned_majority;  // did final choice match weighted majority?
    uint256 session_timestamp;
}
```

**VWUEngine returns:** `vwu_delta` (uint256)

**What MACI does NOT see:** VWU formula internals, non-linear growth factor, continuity adjustment mechanics.

---

## ZK Circuit Requirements

### Identity Circuit (Circom)
```
Inputs (private):
  - biometric_commitment (from L0 FaceID)
  - keystroke_entropy (behavioral fingerprint)

Inputs (public):
  - identity_commitment (bytes32)

Output:
  - valid_registration (bool)

Constraint: biometric_commitment + entropy → identity_commitment
```

### Vote Proof Circuit (Circom)
```
Inputs (private):
  - maci_key (participant's current MACI key)
  - choice (OPTION_A or OPTION_B)
  - nullifier_secret

Inputs (public):
  - nullifier_hash (bytes32)
  - session_id (uint256)

Output:
  - encrypted_message (for MACI MessageProcessor)

Constraint: nullifier has not been used, key is valid for session
```

### Tally Proof Circuit (MACI built-in)
```
Proves: the published tally correctly aggregates all final choices
        without revealing any individual choice
Used by: Verifier.sol (on-chain verification)
```

---

## Coordinator Security Model

The MACI coordinator is protected by Lit Protocol threshold MPC:

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
| L0 | FaceID + behavioral biometrics | Physical device with unique face |
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

### MACI v1.2 Key Parameters

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

- [ ] Deploy MACI contracts (PollFactory, MessageProcessorFactory, TallyFactory)
- [ ] Configure Lit Protocol MPC for coordinator key
- [ ] Deploy ZK verifier contracts (Groth16 or PLONK)
- [ ] Deploy BeTrueCoreCore with MACI coordinator address
- [ ] Deploy EthicalMatrix and populate 736 cells
- [ ] Deploy HarmonyAgent connected to EthicalMatrix
- [ ] Deploy VWUEngine connected to MACI coordinator
- [ ] Configure Celestia DA indexer for event logging
- [ ] Run Foundry tests (see BeTrueCore.t.sol)

### Known Constraints

1. **Coordinator availability:** MACI coordinator must be online to process session. Lit Protocol MPC mitigates single point of failure but does not eliminate availability risk.

2. **ZK proof generation time:** Tally proof generation takes 2–10 minutes depending on session size. Plan coordinator infrastructure accordingly.

3. **Gas costs:** Each MACI message costs ~50k gas on L2. For 100 participants × 3 choice changes = 15M gas per session. Optimism L2 makes this feasible.

4. **Nullifier storage:** ZK nullifiers accumulate over time. Plan for nullifier registry pruning strategy after MVP phase.
