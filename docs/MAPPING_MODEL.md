# BeTrueCore Mapping Model v0
## Evidential Layer Boundary Definition

**Version:** 0.1  

**Repository:** github.com/Dede-Qorqud/BeTrueCore

---

## Overview

The Mapping Model defines the evidential layer boundary between BeTrueCore's internal architecture and external systems. It specifies what data crosses each layer boundary, in which direction, and under what cryptographic guarantees.

---

## Layer Architecture

```
L0  Identity Input          FIN-code ZK-commitment + behavioral entropy + session timing
     ↓
L1  Cryptographic Proof     ZK-SNARKs + anti-collusion protocol (Circom/Groth16) + ZK nullifier + Lit Protocol MPC
     ↓
L2  Execution               Optimism L2 — VWU calculation + smart contract execution
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
| FIN-code ZK-commitment | L0 → L1 | bytes32 hash | State ID verified |
| Behavioral entropy | L0 → L1 | uint256 | VWU behavioral record (see Preprint 11) |
| Session timing | L0 → L1 | uint256 timestamp | Liveness proof |

**What does NOT cross:** Raw FIN-code, state identifier plaintext, behavioral sequences.  
**Guarantee:** No raw FIN-code or state identifier ever leaves L0.

### L1 → L2 Boundary

| Data | Direction | Format | Guarantee |
|------|-----------|--------|-----------|
| ZK identity proof | L1 → L2 | bytes (SNARK) | Valid registration |
| ZK nullifier | L1 → L2 | bytes32 | No double-vote |
| Encrypted choice | L1 → L2 | bytes (anti-collusion protocol) | Receipt-free |
| ZK correctness proof | L1 → L2 | bytes (SNARK) | Coordinator result valid |

**What does NOT cross:** Plaintext choice, participant address, intermediate choices.  
**Guarantee:** Receipt-freeness — no verifiable proof of choice for third parties.

### L2 → L4 Boundary (via L3)

| Data | Direction | Format | Guarantee |
|------|-----------|--------|-----------|
| VWU delta | L2 → L4 | uint256 (scaled ×100) | Post-session update |
| Session result | L2 → L4 | SessionResult struct | Coordinator-verified |
| Ethical verdict | L2 → L4 | Verdict enum | Harmony Agent output |
| CellTriggered events | L2 → L4 | Event log | Immutable audit |

**What does NOT cross:** Individual choices, participant identities, VWU formula internals.  
**Guarantee:** Public verifiability without revealing individual choices.

### L5 Agent Boundary (read-only in all directions)

| Agent | Reads from | Writes to | Function |
|-------|-----------|-----------|----------|
| Analyst × 3 | L0 ZK-commitments, L1 proofs | NOTHING | Signal verification |
| Strategist × 3 | L2 results, L4 audit | NOTHING | Pattern analysis |
| Sentinel × 3 | L0–L4 all layers | NOTHING | Security monitoring |

**Constitutional principle:** AI agents have NO write access to any data structure.  
**"AI is the notary. The human is the author."**

---

## Anti-Collusion Protocol Integration Points

### Key Rotation Protocol

```
Session open
    ↓
Participant submits encrypted choice
    ↓
Participant may rotate key + submit new choice (any number of times)
    ↓
TIME LOCK — session closes
    ↓
Only FINAL choice counts (previous keys invalidated)
    ↓
Coordinator publishes result + ZK correctness proof
    ↓
Coordinator cannot falsify — fraudulent proof rejected by verifiers
```

### Receipt-Freeness Guarantee

A participant cannot demonstrate their final choice to any external party because:
1. All intermediate choices are equally plausible
2. Final choice is cryptographically hidden until after time lock
3. Key-rotation invalidates all intermediate proofs

---

## VWU Calculation Boundary

The VWU formula is a **Black Box** at this boundary layer.

**Inputs (public):**
- `activity_score` (uint8, 0–100) — completeness of session participation
- `aligned_majority` (bool) — whether final choice aligned with weighted majority

**Output (public):**
- `vwu_delta` (uint256) — increment to participant's VWU balance

**Internal mechanics (protected):**
- Non-linear growth factor
- Continuity adjustment algorithm
- Full formula specification

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

Events logged: `CellTriggered`, `VWUUpdated`, `SessionFinalized`, `EthicalVerdictIssued`

---

## Glossary

| Term | Definition |
|------|-----------|
| Receipt-freeness | Property that prevents a participant from proving their choice to third parties |
| Time lock | Session close — after which no choice changes are accepted |
| ZK nullifier | Cryptographic token preventing double-voting |
| VWU | Vote Weight Unit — non-transferable, non-marketable participation weight |
| Anti-collusion protocol | Circom/Groth16 implementation of the MACI pattern for collusion-resistant voting. The MACI repository (appliedzkp/maci) was archived August 19, 2026; BeTrueCore builds on the underlying cryptographic standard. |
| Ematch | Ethical match score (0–1) for each intersection cell in the 736-point matrix |
