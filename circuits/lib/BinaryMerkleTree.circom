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
 * Constraint enforced:
 *   computed_root(leaf, path_elements, path_indices) === root
 *
 * If the proof is invalid → constraint fails → proof rejected on-chain.
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
