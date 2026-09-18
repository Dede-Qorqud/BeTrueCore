pragma circom 2.0.0;

include "circomlib/circuits/poseidon.circom";

/*
 * ═════════════════════════════════════════════════════════════════════════════
 * BeTrueCore — NINCommitment.circom
 * Circuit: Registration Phase — «My identity is my fortress»
 *
 * «Mənim şəxsiyyətim — mənim qalam»
 *
 * Author:  Farman Guliyev (Safarnur)
 * ORCID:   0009-0004-4841-594X
 * GitHub:  github.com/Dede-Qorqud/BeTrueCore
 * Version: 0.1 — MVP Circuit
 * ═════════════════════════════════════════════════════════════════════════════
 *
 * PURPOSE
 * ───────
 * Transforms a citizen's NIN (National Identification Number) into a
 * cryptographic commitment that can be stored on-chain — without ever
 * exposing the raw NIN to any server, coordinator, or AI agent.
 *
 * This circuit is executed ONCE per citizen, at the moment of registration.
 * The output (identity_commitment) becomes a leaf in the on-chain Merkle tree
 * of registered voters. The circuit proves: "I computed this commitment
 * correctly from my NIN and secrets" — without revealing what they are.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * CLIENT-SIDE PRE-COMPUTATION (before the circuit runs):
 *
 *   nin_preimage = field_encode(NIN_string)
 *
 *   For Azerbaijani FIN (7-char alphanumeric):
 *     Each character is mapped to its ASCII value, then packed into
 *     a single 254-bit field element. This is done in the browser
 *     BEFORE any circuit call. The raw NIN never leaves the device.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * COMMITMENT SCHEME (two-layer Poseidon):
 *
 *   Layer 1 — Bind NIN to salt (prevents rainbow table attacks):
 *     nin_key = Poseidon(nin_preimage, registration_salt)
 *
 *   Layer 2 — Bind NIN key to user secret (enables key rotation):
 *     identity_commitment = Poseidon(nin_key, identity_secret)
 *
 *   Two layers are necessary because:
 *   - registration_salt: protects against precomputed NIN tables
 *     (even if salt leaks, attacker cannot link it to a NIN without secret)
 *   - identity_secret: allows a user to rotate their identity without
 *     re-registering (a new secret → new commitment, same NIN)
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * SECURITY PROPERTIES:
 *
 *   ✓ Hiding:   commitment reveals nothing about nin_preimage or secrets
 *   ✓ Binding:  no two different (NIN, salt, secret) triples produce the same
 *               commitment under Poseidon collision resistance
 *   ✓ Private:  NIN raw value never enters any server, log, or contract
 *   ✓ Rotation: user can change identity_secret → new commitment,
 *               same NIN (useful if secret is compromised)
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * PRIVATE INPUTS  (known only to the citizen, never disclosed):
 *
 *   nin_preimage       — NIN encoded as BN254 field element, client-side only
 *   registration_salt  — 254-bit random value, generated once at registration
 *   identity_secret    — 254-bit random value, owned and stored by the user
 *
 * PUBLIC OUTPUT:
 *
 *   identity_commitment — stored as a Merkle leaf in NINNullifierRegistry.sol
 *
 * ═════════════════════════════════════════════════════════════════════════════
 */
template NINCommitment() {

    // ── Private inputs — NEVER disclosed outside the prover's device ─────
    signal input nin_preimage;       // encode(NIN_raw) — computed client-side
    signal input registration_salt;  // random 254-bit, generated at registration
    signal input identity_secret;    // random 254-bit, owned by user

    // ── Public output — stored on-chain as Merkle leaf ───────────────────
    signal output identity_commitment;

    // ── Step 1: nin_key = Poseidon(nin_preimage, registration_salt) ───────
    // Binds the NIN to a random salt → rainbow table attacks impossible
    component nin_hasher = Poseidon(2);
    nin_hasher.inputs[0] <== nin_preimage;
    nin_hasher.inputs[1] <== registration_salt;

    signal nin_key <== nin_hasher.out;

    // ── Step 2: commitment = Poseidon(nin_key, identity_secret) ──────────
    // Binds nin_key to user secret → enables key rotation
    component commitment_hasher = Poseidon(2);
    commitment_hasher.inputs[0] <== nin_key;
    commitment_hasher.inputs[1] <== identity_secret;

    identity_commitment <== commitment_hasher.out;

    // ── Implicit constraints guaranteed by Poseidon template: ────────────
    //   All inputs are valid BN254 field elements (< p)
    //   Output is deterministic: same inputs → same commitment
    //   Collision resistance inherited from Poseidon security proof
}

// ── Main component ────────────────────────────────────────────────────────
// No public inputs — the commitment is the only public value.
// The prover generates the commitment locally and sends it to the registry.
component main {public []} = NINCommitment();
