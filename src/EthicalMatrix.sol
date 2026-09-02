// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title EthicalMatrix
/// @notice Stores the 736-point ethical priority map (23 Asilomar Principles × 32 TDSH parameters)
/// @dev Part of BeTrueCore Developer Package v0.2
/// @author Farman Guliyev (Safarnur) — github.com/Dede-Qorqud/BeTrueCore

contract EthicalMatrix {

    // ─────────────────────────────────────────────────────────────
    // ENUMS
    // ─────────────────────────────────────────────────────────────

    /// @notice Priority level of each intersection cell
    enum CellState {
        SUPERPOSITION,  // weight 0 · potential connection, not yet active
        MEDIUM,         // weight 1 · indirect intersection, background control
        HIGH,           // weight 2 · significant intersection
        CRITICAL        // weight 3 · direct intersection, safety-critical
    }

    /// @notice Agent group responsible for each cell
    enum AgentType {
        ANALYST,        // verification · signal authenticity · VWU 1-3
        STRATEGIST,     // values · ethics · coordination · VWU 4-6
        SENTINEL        // security · long-term risk · VWU 7-9
    }

    /// @notice Traffic light verdict
    enum Verdict {
        RED,            // Ematch < 0.4 · integrity threshold breached
        YELLOW,         // Ematch 0.4–0.7 · partial degradation detected
        GREEN           // Ematch >= 0.7 · collective judgment integrity confirmed
    }

    // ─────────────────────────────────────────────────────────────
    // STRUCTS
    // ─────────────────────────────────────────────────────────────

    /// @notice Single intersection cell in the 23×32 matrix
    struct EthicalCell {
        uint8     asilomar_id;   // A01–A23 (1–23)
        uint8     tdsh_id;       // T01–T32 (1–32)
        CellState priority;      // SUPERPOSITION / MEDIUM / HIGH / CRITICAL
        AgentType agent;         // ANALYST / STRATEGIST / SENTINEL
    }

    // ─────────────────────────────────────────────────────────────
    // STATE
    // ─────────────────────────────────────────────────────────────

    /// @notice 736 cells stored as mapping
    /// @dev Key = asilomar_id * 100 + tdsh_id
    mapping(uint16 => EthicalCell) public cells;

    address public owner;

    // ─────────────────────────────────────────────────────────────
    // EVENTS
    // ─────────────────────────────────────────────────────────────

    event CellTriggered(
        bytes32 indexed identity_commitment,
        uint8   asilomar_id,
        uint8   tdsh_id,
        uint8   ematch_score,    // 0–100 (scaled from 0.0–1.0)
        Verdict verdict
    );

    event MatrixPopulated(uint256 cell_count);

    // ─────────────────────────────────────────────────────────────
    // CONSTRUCTOR
    // ─────────────────────────────────────────────────────────────

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // ─────────────────────────────────────────────────────────────
    // MATRIX POPULATION
    // ─────────────────────────────────────────────────────────────

    /// @notice Populate a batch of cells
    /// @dev Called by deployer to fill the 736-point map
    function populateCells(
        uint8[]     memory asilomar_ids,
        uint8[]     memory tdsh_ids,
        CellState[] memory priorities,
        AgentType[] memory agents
    ) external onlyOwner {
        require(
            asilomar_ids.length == tdsh_ids.length &&
            tdsh_ids.length == priorities.length &&
            priorities.length == agents.length,
            "Array length mismatch"
        );

        for (uint i = 0; i < asilomar_ids.length; i++) {
            uint16 key = uint16(asilomar_ids[i]) * 100 + uint16(tdsh_ids[i]);
            cells[key] = EthicalCell({
                asilomar_id: asilomar_ids[i],
                tdsh_id:     tdsh_ids[i],
                priority:    priorities[i],
                agent:       agents[i]
            });
        }

        emit MatrixPopulated(asilomar_ids.length);
    }

    // ─────────────────────────────────────────────────────────────
    // CORE FUNCTIONS
    // ─────────────────────────────────────────────────────────────

    /// @notice Get the weight of a cell (0–3)
    /// @param asilomar_id Asilomar Principle ID (1–23)
    /// @param tdsh_id TDSH Parameter ID (1–32)
    /// @return weight 0=SUPERPOSITION, 1=MEDIUM, 2=HIGH, 3=CRITICAL
    function getCellWeight(
        uint8 asilomar_id,
        uint8 tdsh_id
    ) public view returns (uint8) {
        CellState priority = cells[
            uint16(asilomar_id) * 100 + uint16(tdsh_id)
        ].priority;

        if (priority == CellState.CRITICAL)     return 3;
        if (priority == CellState.HIGH)         return 2;
        if (priority == CellState.MEDIUM)       return 1;
        return 0; // SUPERPOSITION
    }

    /// @notice Map Ematch score (0–100) to traffic light verdict
    /// @param ematch_score Aggregated Ematch score scaled to 0–100
    /// @return verdict RED / YELLOW / GREEN
    function computeVerdict(
        uint8 ematch_score
    ) public pure returns (Verdict) {
        if (ematch_score < 40) return Verdict.RED;
        if (ematch_score < 70) return Verdict.YELLOW;
        return Verdict.GREEN;
    }

    /// @notice Get the agent type responsible for a cell
    function getCellAgent(
        uint8 asilomar_id,
        uint8 tdsh_id
    ) public view returns (AgentType) {
        return cells[uint16(asilomar_id) * 100 + uint16(tdsh_id)].agent;
    }

    /// @notice Get full cell data
    function getCell(
        uint8 asilomar_id,
        uint8 tdsh_id
    ) external view returns (EthicalCell memory) {
        return cells[uint16(asilomar_id) * 100 + uint16(tdsh_id)];
    }

    /// @notice Emit CellTriggered event (called by HarmonyAgent)
    function triggerCell(
        bytes32 identity_commitment,
        uint8 asilomar_id,
        uint8 tdsh_id,
        uint8 ematch_score
    ) external {
        Verdict verdict = computeVerdict(ematch_score);
        emit CellTriggered(identity_commitment, asilomar_id, tdsh_id, ematch_score, verdict);
    }
}
