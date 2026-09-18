pragma circom 2.0.0;

include "circomlib/circuits/poseidon.circom";
include "./lib/BinaryMerkleTree.circom";

/*
 * ═════════════════════════════════════════════════════════════════════════════
 * BeTrueCore — NINIdentityProof.circom
 * Circuit: Voting Phase — «The notary bears witness»
 *
 * Author:  Farman Guliyev (Safarnur)
 * ORCID:   0009-0004-4841-594X
 * GitHub:  github.com/Dede-Qorqud/BeTrueCore
 * Version: 0.1 — MVP Circuit
 * ═════════════════════════════════════════════════════════════════════════════
 *
 * PURPOSE
 * ───────
 * Proves that a citizen is a registered unique participant in BeTrueCore
 * and generates a session-specific nullifier — WITHOUT revealing WHICH
 * citizen they are or how they voted.
 *
 * This circuit is the cryptographic bridge between L0 (Identity) and L1
 * (Proofs) in the BeTrueCore architecture. It is executed by the citizen's
 * device during each voting session.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * WHAT THIS PROOF GUARANTEES (simultaneously):
 *
 *   1. UNIQUENESS:    The prover knows a (NIN, salt, secret) whose commitment
 *                     is a valid leaf in the registered voter Merkle tree.
 *                     → "I am a real registered citizen."
 *
 *   2. ANONYMITY:     The commitment used is not revealed to anyone.
 *                     The verifier only sees the Merkle root and the nullifier.
 *                     → "I cannot be identified by my vote."
 *
 *   3. ANTI-SYBIL:    The nullifier is deterministically derived from
 *                     (identity_secret, session_id). If the same citizen tries
 *                     to enter the same session as two different identities:
 *                     same inputs → same nullifier → second entry rejected.
 *                     → "I cannot enter the session as two citizens."
 *                     NOTE: Multiple choice changes WITHIN the session are
 *                     explicitly PERMITTED — this is the anti-coercion
 *                     mechanism. Key rotation (Poll.sol) handles this.
 *                     Only the FINAL choice is counted at time lock.
 *
 *   4. CROSS-SESSION: A different session_id → a different nullifier.
 *                     A user's nullifier from session 1 cannot be linked
 *                     to their nullifier from session 2.
 *                     → "My participation history is unlinkable."
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * PARAMETERS:
 *
 *   LEVELS — depth of the registered voter Merkle tree
 *            LEVELS = 20 supports up to 2^20 = 1,048,576 participants
 *            For pilot (50–100 users): LEVELS = 7 sufficient (2^7 = 128)
 *            Change the component main declaration at the bottom to adjust.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * PRIVATE INPUTS (known only to the citizen, never disclosed):
 *
 *   nin_preimage           — NIN encoded as field element, client-side only
 *   registration_salt      — salt from initial registration (user stores)
 *   identity_secret        — user's secret (user stores, enables nullifier)
 *   path_elements[LEVELS]  — sibling nodes along the Merkle path
 *   path_indices[LEVELS]   — directions: 0=current is left, 1=current is right
 *
 * PUBLIC INPUTS (known to verifier, stored on-chain):
 *
 *   merkle_root            — current root of registered voter tree (on-chain)
 *   external_nullifier     — session_id from Poll.sol (changes each session)
 *
 * PUBLIC OUTPUT (output of the ZK proof, checked on-chain):
 *
 *   nullifier              — unique per (citizen × session); stored on-chain
 *                            to prevent Sybil entry (one citizen = one session
 *                            ticket). Does NOT prevent choice changes — those
 *                            are handled by Poll.sol key rotation (MACI pattern)
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * NULLIFIER SCHEME:
 *
 *   nullifier = Poseidon(identity_secret, external_nullifier)
 *
 *   Why identity_secret, not nin_key?
 *     If nullifier = Poseidon(nin_key, session_id), then a compromise of
 *     registration_salt would allow linking nullifiers across sessions.
 *     Using identity_secret (which is independent of NIN) means:
 *     - Nullifier reveals nothing about the NIN even if partially analysed
 *     - User can rotate identity_secret → new nullifiers, same NIN, safe
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * CIRCUIT FLOW:
 *
 *   Step 1: Reconstruct identity_commitment from private inputs
 *           (same computation as NINCommitment.circom)
 *
 *   Step 2: Verify that identity_commitment is in the Merkle tree
 *           with root = merkle_root  (via BinaryMerkleTree)
 *
 *   Step 3: Compute session-specific nullifier
 *           nullifier = Poseidon(identity_secret, external_nullifier)
 *
 * ═════════════════════════════════════════════════════════════════════════════
 */
template NINIdentityProof(LEVELS) {

    // ── Private inputs ───────────────────────────────────────────────────
    signal input nin_preimage;              // NIN field element — client only
    signal input registration_salt;         // random salt from registration
    signal input identity_secret;           // user secret — source of nullifier
    signal input path_elements[LEVELS];     // Merkle path sibling values
    signal input path_indices[LEVELS];      // Merkle path directions (0 or 1)

    // ── Public inputs ────────────────────────────────────────────────────
    signal input merkle_root;               // on-chain: current voter tree root
    signal input external_nullifier;        // on-chain: session_id from Poll.sol

    // ── Public output ────────────────────────────────────────────────────
    signal output nullifier;                // on-chain: checked, then stored

    // ════════════════════════════════════════════════════════════════════
    // STEP 1 — Reconstruct identity_commitment
    // Same two-layer Poseidon scheme as NINCommitment.circom
    // The circuit CONSTRAINS that the prover knows valid private inputs.
    // ════════════════════════════════════════════════════════════════════

    // Layer 1: nin_key = Poseidon(nin_preimage, registration_salt)
    component nin_hasher = Poseidon(2);
    nin_hasher.inputs[0] <== nin_preimage;
    nin_hasher.inputs[1] <== registration_salt;
    signal nin_key <== nin_hasher.out;

    // Layer 2: identity_commitment = Poseidon(nin_key, identity_secret)
    component commitment_hasher = Poseidon(2);
    commitment_hasher.inputs[0] <== nin_key;
    commitment_hasher.inputs[1] <== identity_secret;
    signal identity_commitment <== commitment_hasher.out;

    // ════════════════════════════════════════════════════════════════════
    // STEP 2 — Verify Merkle membership
    // Proves: identity_commitment is a valid leaf in the registered tree.
    // If the proof path is wrong → constraint fails → proof rejected.
    // ════════════════════════════════════════════════════════════════════

    component merkle_checker = BinaryMerkleTree(LEVELS);
    merkle_checker.leaf <== identity_commitment;
    merkle_checker.root <== merkle_root;

    for (var i = 0; i < LEVELS; i++) {
        merkle_checker.path_elements[i] <== path_elements[i];
        merkle_checker.path_indices[i]  <== path_indices[i];
    }

    // ════════════════════════════════════════════════════════════════════
    // STEP 3 — Generate session-specific nullifier
    //
    // nullifier = Poseidon(identity_secret, external_nullifier)
    //
    // Properties:
    //   - Same citizen, same session → same nullifier → Sybil entry rejected
    //     (one citizen cannot enter the session as two different identities)
    //   - Same citizen, same session → choice CAN change multiple times via
    //     Poll.sol key rotation — this is the anti-coercion mechanism.
    //     Only the final key's choice is counted. This circuit does NOT
    //     constrain choice changes — that is Poll.sol's responsibility.
    //   - Different sessions   → different nullifiers → sessions unlinkable
    //   - Nullifier alone does not reveal identity_commitment or NIN
    // ════════════════════════════════════════════════════════════════════

    component nullifier_hasher = Poseidon(2);
    nullifier_hasher.inputs[0] <== identity_secret;
    nullifier_hasher.inputs[1] <== external_nullifier;
    nullifier <== nullifier_hasher.out;

    // ── Summary of enforced constraints: ────────────────────────────────
    //
    //   (1) nin_key              = Poseidon(nin_preimage, registration_salt)
    //   (2) identity_commitment  = Poseidon(nin_key, identity_secret)
    //   (3) identity_commitment  ∈ MerkleTree(merkle_root)
    //   (4) nullifier            = Poseidon(identity_secret, external_nullifier)
    //
    //   All four must hold simultaneously for the proof to be valid.
    //   Violating any one → verifier rejects the proof on-chain.
}

// ── Main component ────────────────────────────────────────────────────────
//
// LEVELS = 20 → production (up to 1,048,576 participants)
// LEVELS = 7  → pilot (up to 128 participants) — change here for pilot
//
// Public signals declared explicitly:
//   merkle_root and external_nullifier are public inputs (verifier knows them)
//   nullifier is the public output (written to chain as used nullifier)
//
component main {public [merkle_root, external_nullifier]} = NINIdentityProof(20);
