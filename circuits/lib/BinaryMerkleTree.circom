pragma circom 2.0.0;

include "circomlib/circuits/poseidon.circom";
include "circomlib/circuits/mux1.circom";

/*
 * ─────────────────────────────────────────────────────────────────────────────
 * BeTrueCore — BinaryMerkleTree
 * "The mirror reflects. The notary bears witness. The matrix measures."
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Verifies a Merkle inclusion proof for a binary Poseidon hash tree.
 *
 * Poseidon hash is ZK-friendly (designed for arithmetic circuits) and
 * produces on-chain verifier contracts that are ~10× cheaper in gas
 * than SHA-256 or Pedersen. This is the standard choice for all major
 * ZK identity protocols (Semaphore, Tornado Cash, Aztec).
 *
 * Parameters:
 *   LEVELS — depth of the Merkle tree
 *             LEVELS = 20 → 2^20 = 1,048,576 participants maximum
 *
 * Signals (inputs):
 *   leaf                  — the leaf value (identity_commitment)
 *   root                  — expected Merkle root (public, stored on-chain)
 *   path_elements[LEVELS] — sibling node at each level of the path
 *   path_indices[LEVELS]  — direction at each level:
 *                           0 → current node is the LEFT child
 *                           1 → current node is the RIGHT child
 *
 * Constraints enforced:
 *   (1) path_indices[i] is 0 or 1 at every level — see the note at that line
 *   (2) computed_root(leaf, path_elements, path_indices) === root
 *
 * If the proof is invalid → constraint fails → proof rejected on-chain.
 *
 * WHAT THIS TEMPLATE DOES NOT PROVE — state it this way wherever membership
 * is described. It proves that a leaf lies under the root it was given. It
 * says nothing about where that root came from. A transition from one root to
 * the next — that the new root is the old one with exactly the announced
 * commitments inserted, and nothing else — is not expressed here, and no
 * published artefact of this project expresses it today. The tree is built
 * off-chain and only its root reaches the contract, so a root carrying a leaf
 * nobody chose verifies exactly as well as an honest one, and every proof
 * against it succeeds.
 * Membership therefore rests on trust in whoever computes the root, and that
 * is to be named as organisational wherever the roster is called closed. The
 * primitive still absent is a third-party-verifiable proof of set equality
 * that discloses no counts; it is the `not established` row of the
 * requirements table (WHITEPAPER.md 5.6, docs/AUTHORITY_CHAIN.md §14).
 *
 * NO DOMAIN SEPARATION between leaves and internal nodes: both are outputs of
 * Poseidon(2), and nothing in this template tells them apart. Today that is
 * harmless only because of how the caller builds the leaf — in
 * NINIdentityProof.circom the leaf is Poseidon(Poseidon(nin, salt), secret),
 * so passing an internal node off as a leaf would require a Poseidon preimage.
 * The protection lives in the caller, not here. If the leaf construction ever
 * changes — a single-layer leaf, or a commitment accepted as a free input —
 * this template will accept an internal node as a leaf without any warning.
 * ─────────────────────────────────────────────────────────────────────────────
 */
template BinaryMerkleTree(LEVELS) {

    signal input leaf;
    signal input root;
    signal input path_elements[LEVELS];
    signal input path_indices[LEVELS];

    // Intermediate computed hashes at each level
    signal computed[LEVELS + 1];
    computed[0] <== leaf;

    component hashers[LEVELS];
    component left_sel[LEVELS];
    component right_sel[LEVELS];

    for (var i = 0; i < LEVELS; i++) {

        // ── Binary constraint: path_indices[i] must be 0 or 1 ───────────
        // Mux1 does NOT constrain its selector: its output is linear in s,
        // so a non-binary s would blend the two inputs and let a prover steer
        // the computed root. This line is the only thing that forbids it —
        // it is not redundant with the multiplexers below.
        path_indices[i] * (1 - path_indices[i]) === 0;

        // ── Select which value is the LEFT input to the hash ─────────────
        // path_indices[i] = 0 → current node is left  → left = computed[i]
        // path_indices[i] = 1 → current node is right → left = sibling
        left_sel[i] = Mux1();
        left_sel[i].c[0] <== computed[i];       // s=0: current is left
        left_sel[i].c[1] <== path_elements[i];  // s=1: sibling is left
        left_sel[i].s    <== path_indices[i];

        // ── Select which value is the RIGHT input to the hash ────────────
        // path_indices[i] = 0 → current node is left  → right = sibling
        // path_indices[i] = 1 → current node is right → right = computed[i]
        right_sel[i] = Mux1();
        right_sel[i].c[0] <== path_elements[i]; // s=0: sibling is right
        right_sel[i].c[1] <== computed[i];      // s=1: current is right
        right_sel[i].s    <== path_indices[i];

        // ── Hash left || right → next level ─────────────────────────────
        hashers[i] = Poseidon(2);
        hashers[i].inputs[0] <== left_sel[i].out;
        hashers[i].inputs[1] <== right_sel[i].out;

        computed[i + 1] <== hashers[i].out;
    }

    // ── Final constraint: computed root must match on-chain root ─────────
    root === computed[LEVELS];
}