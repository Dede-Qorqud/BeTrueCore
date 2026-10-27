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
 * correctly from the values I supplied" — without revealing what they are.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * WHAT THIS CIRCUIT PROVES — AND WHAT IT DOES NOT:
 *
 *   Proven: knowledge of three field elements whose two-layer Poseidon hash
 *   equals this commitment. A proof of knowledge of a preimage, nothing more.
 *
 *   NOT proven: that nin_preimage encodes a real National Identification
 *   Number; that the number was confirmed by the e-government gateway; that
 *   one citizen holds one leaf. No signal in this circuit originates outside
 *   the prover's device, so any three field elements yield a valid proof.
 *
 *   Gateway verification of the NIN exists in the architecture at L0, but it
 *   runs in the client, not here. Nothing cryptographic binds "the gateway
 *   confirmed this number" to "this leaf": that binding rests on the client
 *   software. Binding it inside the circuit would require an attestation
 *   signed by the gateway as a private input, with the gateway's public key
 *   as a public input. Until that is built, the guarantee must not be stated
 *   as proven anywhere in the project.
 *
 *   In the current construction this proof has no verifier: the tree root is
 *   set by a single address in contracts/NINNullifierRegistry.sol and leaves
 *   are computed off-chain.
 *
 *   COST OF AN EXTRA LEAF (lens B7, 17.10.2026): zero inside this circuit.
 *   All three inputs are free private values, so a second, tenth or thousandth
 *   commitment costs one more proof computation and nothing else. No work, no
 *   stake, no vouching, no synchronous ceremony and no human-versus-machine
 *   test stands between an operator and an extra leaf. This is not a new
 *   effect of AI agents: there is no test here for an agent to pass, so
 *   automation changes nothing about the cost. What limits the number of
 *   leaves lies entirely outside this circuit, in two places: the client,
 *   which is expected to run the gateway check before computing a commitment,
 *   and whoever writes the Merkle root on-chain. Both are organisational
 *   guarantees, not cryptographic ones, and both must be named as such
 *   wherever Sybil resistance is claimed for L0.
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
 *   REQUIRED OF THE CLIENT (not enforced here): the gateway check and this
 *   encoding are one unbroken step. nin_preimage must encode the very number
 *   the e-government gateway has just confirmed, and the client must offer no
 *   path that builds a commitment from a number which did not pass that check.
 *   This is an implementation obligation: nothing on-chain verifies it, and a
 *   modified or re-implemented client bypasses it completely. Stated here
 *   because an engineer reading this file as a specification would otherwise
 *   build a client that simply accepts a typed number.
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
 *               commitment under Poseidon collision resistance. This binds
 *               the commitment to the triple, not the triple to a citizen:
 *               the circuit receives no gateway attestation and therefore
 *               does not prove that nin_preimage is anyone's real NIN.
 *               See WHAT THIS CIRCUIT PROVES above.
 *   ✓ Private:  NIN raw value never enters any server, log, or contract.
 *               The commitment does: it is written on-chain as a Merkle leaf,
 *               and if the citizen submits it themselves, the sending address
 *               is bound to it permanently. Registration is the single moment
 *               where that link is strongest.
 *   ⚠ Rotation: changing identity_secret yields a new commitment for the same
 *               NIN. Useful if the secret is compromised — but only if the old
 *               leaf is retired at the same time. Two live leaves for one NIN
 *               means two nullifiers in one session, which is exactly what the
 *               anti-Sybil property of NINIdentityProof.circom rules out.
 *               Retiring a leaf without linking it to the new one is an open
 *               problem; until it is settled, rotation is not offered.
 *               Rotation is the narrow case of a wider one: the circuit binds
 *               a commitment to a triple of numbers, and nothing binds that
 *               triple to a person. Many live leaves can be built from freely
 *               chosen values, with or without a real NIN behind any of them.
 *               Reading this note alone leaves the impression that retiring
 *               old leaves would close the gap. It would not.
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

    signal nin_key;
    nin_key <== nin_hasher.out;

    // ── Step 2: commitment = Poseidon(nin_key, identity_secret) ──────────
    // Binds nin_key to user secret → enables key rotation
    component commitment_hasher = Poseidon(2);
    commitment_hasher.inputs[0] <== nin_key;
    commitment_hasher.inputs[1] <== identity_secret;

    identity_commitment <== commitment_hasher.out;

    // ── What the Poseidon template does and does not give us: ────────────
    //   Output is deterministic: same inputs → same commitment
    //   Collision resistance inherited from Poseidon security proof
    //
    //   NOT a guarantee: "all inputs are valid BN254 field elements (< p)".
    //   In Circom every signal is a field element by definition of the
    //   language, so that statement is true but empty: Poseidon adds nothing
    //   to it.
    //
    //   MISSING CONSTRAINT: the range of nin_preimage is not constrained at
    //   all. The client packs a 7-character FIN into one field element, using
    //   about 56 of its 254 bits, and this circuit accepts any field element
    //   in its place. A range check (Num2Bits) is deliberately NOT added
    //   here: it would fix the shape of the encoding without making the value
    //   a verified number, and any fixed width would also have to hold for
    //   the residence code of lawfully resident foreigners, who register
    //   through the same gateway. The width belongs to the encoding
    //   specification, not to this circuit.
}

// ── Main component ────────────────────────────────────────────────────────
// No public inputs — the commitment is the only public value.
// The prover generates the commitment locally and sends it to the registry.
// The public list is omitted on purpose: circom's grammar requires at least
// one identifier inside {public [...]}, so an empty list does not parse. An
// output signal is public in any case, by the definition of the language.
component main = NINCommitment();