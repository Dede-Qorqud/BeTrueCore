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
 * Proves that the prover holds the secrets behind ONE LEAF of the registered
 * Merkle tree, and generates a session-specific nullifier — WITHOUT revealing
 * WHICH leaf it is or how they voted.
 *
 * Note the wording: one leaf, not one citizen. The step from "one leaf" to
 * "one citizen" is not enforced here — see ANTI-SYBIL below.
 *
 * This circuit is the cryptographic bridge between L0 (Identity) and L1
 * (Proofs) in the BeTrueCore architecture. It is executed by the citizen's
 * device during each voting session.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * WHAT THIS PROOF GUARANTEES (simultaneously):
 *
 *   1. MEMBERSHIP:    The prover knows a (NIN, salt, secret) whose commitment
 *                     is a valid leaf in the registered voter Merkle tree.
 *                     → "I know the secrets behind one leaf of this tree."
 *                     NOT "I am a real citizen": no gateway attestation enters
 *                     this circuit, so whether that leaf belongs to a verified
 *                     National Identification Number is settled outside it.
 *                     See NINCommitment.circom.
 *
 *   2. ANONYMITY:     The commitment used is not revealed to anyone.
 *                     The verifier only sees the Merkle root and the nullifier.
 *                     → "My commitment is not disclosed by this proof."
 *                     The anonymity set is the set of citizens registered under
 *                     that root — not the capacity of the tree. In a community
 *                     of fifty, the proof says "one of fifty", and that is the
 *                     whole of what it says.
 *
 *   3. ANTI-SYBIL:    The nullifier is deterministically derived from
 *                     (identity_secret, external_nullifier). identity_secret
 *                     is one of the preimages of the leaf, so for a given leaf
 *                     the nullifier is fixed within a session:
 *                     one leaf → one nullifier → second entry rejected.
 *                     → "I cannot enter one session twice with one secret."
 *
 *                     NOT "one citizen, one ticket". Two leaves carrying two
 *                     different secrets produce two nullifiers in the same
 *                     session. Nothing binds one citizen to one live leaf:
 *                     neither this circuit, which sees no attestation, nor the
 *                     chain, where the tree is assembled off-chain and the
 *                     root is written by a single address. Secret rotation
 *                     (NINCommitment.circom) is one case of this, not all of
 *                     it.
 *
 *                     NOTE: Multiple choice changes WITHIN the session are
 *                     explicitly PERMITTED. They rest on MESSAGE KEY rotation
 *                     in Poll.sol, which is a different mechanism from the
 *                     secret rotation named just above. Only the FINAL
 *                     choice is counted at time lock.
 *
 *                     What re-choice buys, stated exactly: a coercer who
 *                     demands proof of a choice made earlier in the session
 *                     gets nothing, because that choice can be overwritten and
 *                     the record keeps only the last one. It does not make
 *                     coercion fail. It holds on two premises, both outside
 *                     this circuit: that the coercer is not watching at the
 *                     moment of the last change, and that the message key has
 *                     not been handed over. A coercer holding the key rotates
 *                     it last and overwrites the choice himself. Call this
 *                     re-choice, not "the anti-coercion mechanism".
 *
 *   4. CROSS-SESSION: A different session_id → a different nullifier.
 *                     A user's nullifier from session 1 cannot be linked
 *                     to their nullifier from session 2.
 *                     → "My nullifiers do not link my sessions."
 *                     What this proof does not cover: it travels in a
 *                     transaction sent from the participant's address, and one
 *                     wallet reused across sessions links those sessions
 *                     whatever the nullifier scheme does. The same address
 *                     also makes the FACT of entry visible: anyone who knows
 *                     which address belongs to a person sees that the person
 *                     entered this session, without learning the choice. A
 *                     coercer demanding abstention therefore has something to
 *                     check — the choice is closed, the entry is not. Both are
 *                     relayer questions, not circuit questions.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * PARAMETERS:
 *
 *   LEVELS — depth of the registered voter Merkle tree
 *            LEVELS = 20 supports up to 2^20 = 1,048,576 participants
 *            For pilot (50–100 users): LEVELS = 7 sufficient (2^7 = 128)
 *
 *            The depth is part of the definition of the root: the same set of
 *            participants hashed at another depth yields another root, every
 *            precomputed path stops matching, and every proof already issued
 *            becomes invalid. So it cannot be changed here alone. It changes
 *            in three places at once — this circuit, the off-chain tree
 *            builder, and the root written into the registry — and only while
 *            registration is stopped, because the registry holds a single
 *            root with no window of accepted earlier ones.
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
 *   nullifier              — unique per (leaf × session); stored on-chain to
 *                            reject a second entry under the same secret. Not
 *                            "one citizen, one ticket": nothing here binds a
 *                            citizen to a single live leaf — see ANTI-SYBIL
 *                            above. Does NOT prevent choice changes — those
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
    signal nin_key;
    nin_key <== nin_hasher.out;

    // Layer 2: identity_commitment = Poseidon(nin_key, identity_secret)
    component commitment_hasher = Poseidon(2);
    commitment_hasher.inputs[0] <== nin_key;
    commitment_hasher.inputs[1] <== identity_secret;
    signal identity_commitment;
    identity_commitment <== commitment_hasher.out;

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
    //   - Same leaf, same session → same nullifier → second entry rejected
    //     (one secret cannot enter the session as two different identities;
    //     two leaves with two secrets still give two nullifiers)
    //   - Same leaf, same session → choice CAN change multiple times via
    //     Poll.sol key rotation. Only the final key's choice is counted. This
    //     makes an earlier choice unprovable to a coercer; it does not defeat
    //     coercion, which needs the coercer absent at the last change and the
    //     message key still with the participant. This circuit does NOT
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
    //   (5) every path_indices[i] is 0 or 1 — enforced inside
    //       lib/BinaryMerkleTree.circom, not here. Without it (3) would not
    //       hold: the multiplexers are linear in that selector, so a
    //       non-binary value would let a prover steer the computed root.
    //
    //   All five must hold simultaneously for the proof to be valid.
    //   Violating any one → verifier rejects the proof on-chain.
    //
    //   Note what is NOT an input: the leaf. It is recomputed here by (1) and
    //   (2), so membership cannot be claimed for a value whose Poseidon
    //   preimages the prover does not know — including the filler values of
    //   the tree's empty slots, which anyone can compute. That is why a tree
    //   of depth 20 holding fifty participants is not a hole.
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