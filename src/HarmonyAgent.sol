// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./EthicalMatrix.sol";

/// @title HarmonyAgent
/// @notice Aggregates Ematch scores across activated cells and computes the final traffic light verdict
/// @dev Part of BeTrueCore Developer Package v0.2
/// @author Farman Guliyev (Safarnur) — github.com/Dede-Qorqud/BeTrueCore
///
/// Formula: Ematch_final = Σ(Ematch_ij × weight_ij) / Σ(weight_ij)
/// Verdict: RED [0–40) · YELLOW [40–70) · GREEN [70–100]
///
/// The verdict is applied equally to majority and minority positions.
/// The matrix does not choose sides — it measures both.

contract HarmonyAgent {

    // ─────────────────────────────────────────────────────────────
    // STATE
    // ─────────────────────────────────────────────────────────────

    EthicalMatrix public matrix;
    address public owner;

    // ─────────────────────────────────────────────────────────────
    // EVENTS
    // ─────────────────────────────────────────────────────────────

    /// @notice Emitted after each verdict computation
    event VerdictComputed(
        bytes32 indexed identity_commitment,
        uint256 aggregate_score,
        EthicalMatrix.Verdict verdict,
        uint256 cells_activated,
        bool    is_majority           // true = majority position · false = minority
    );

    // ─────────────────────────────────────────────────────────────
    // CONSTRUCTOR
    // ─────────────────────────────────────────────────────────────

    constructor(address _matrix) {
        matrix = EthicalMatrix(_matrix);
        owner  = msg.sender;
    }

    // ─────────────────────────────────────────────────────────────
    // CORE FUNCTION
    // ─────────────────────────────────────────────────────────────

    /// @notice Compute the final weighted Ematch verdict for a participant
    /// @param identity_commitment ZK identity commitment of the participant
    /// @param asilomar_ids Array of activated Asilomar Principle IDs
    /// @param tdsh_ids Array of activated TDSH Parameter IDs
    /// @param ematch_scores Local Ematch score for each activated cell (0–100)
    /// @param is_majority Whether this participant is in the majority position
    /// @return verdict RED / YELLOW / GREEN
    /// @return aggregate_score Weighted aggregate Ematch (0–100)
    function computeFinalVerdict(
        bytes32   identity_commitment,
        uint8[]   memory asilomar_ids,
        uint8[]   memory tdsh_ids,
        uint8[]   memory ematch_scores,
        bool      is_majority
    ) external returns (
        EthicalMatrix.Verdict verdict,
        uint256 aggregate_score
    ) {
        require(
            asilomar_ids.length == tdsh_ids.length &&
            tdsh_ids.length == ematch_scores.length,
            "Array length mismatch"
        );

        uint256 weighted_sum  = 0;
        uint256 weight_total  = 0;
        uint256 cells_active  = 0;

        for (uint i = 0; i < asilomar_ids.length; i++) {
            uint8 weight = matrix.getCellWeight(asilomar_ids[i], tdsh_ids[i]);

            // SUPERPOSITION cells (weight 0) are excluded from aggregation
            if (weight == 0) continue;

            weighted_sum += uint256(ematch_scores[i]) * uint256(weight);
            weight_total += uint256(weight);
            cells_active++;

            // Emit individual cell trigger to Celestia DA audit trail
            matrix.triggerCell(
                identity_commitment,
                asilomar_ids[i],
                tdsh_ids[i],
                ematch_scores[i]
            );
        }

        // If no cells activated — default GREEN (no violations detected)
        if (weight_total == 0) {
            emit VerdictComputed(identity_commitment, 100, EthicalMatrix.Verdict.GREEN, 0, is_majority);
            return (EthicalMatrix.Verdict.GREEN, 100);
        }

        aggregate_score = weighted_sum / weight_total;
        verdict = matrix.computeVerdict(uint8(aggregate_score));

        emit VerdictComputed(identity_commitment, aggregate_score, verdict, cells_active, is_majority);
    }

    // ─────────────────────────────────────────────────────────────
    // VIEW FUNCTIONS
    // ─────────────────────────────────────────────────────────────

    /// @notice Preview verdict without writing to state (for off-chain simulation)
    function previewVerdict(
        uint8[] memory asilomar_ids,
        uint8[] memory tdsh_ids,
        uint8[] memory ematch_scores
    ) external view returns (
        EthicalMatrix.Verdict verdict,
        uint256 aggregate_score,
        uint256 cells_activated
    ) {
        require(
            asilomar_ids.length == tdsh_ids.length &&
            tdsh_ids.length == ematch_scores.length,
            "Array length mismatch"
        );

        uint256 weighted_sum = 0;
        uint256 weight_total = 0;
        uint256 cells_active = 0;

        for (uint i = 0; i < asilomar_ids.length; i++) {
            uint8 weight = matrix.getCellWeight(asilomar_ids[i], tdsh_ids[i]);
            if (weight == 0) continue;
            weighted_sum += uint256(ematch_scores[i]) * uint256(weight);
            weight_total += uint256(weight);
            cells_active++;
        }

        if (weight_total == 0) {
            return (EthicalMatrix.Verdict.GREEN, 100, 0);
        }

        aggregate_score  = weighted_sum / weight_total;
        verdict          = matrix.computeVerdict(uint8(aggregate_score));
        cells_activated  = cells_active;
    }
}
