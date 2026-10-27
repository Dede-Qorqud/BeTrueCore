
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title EthicalMatrix
/// @notice Stores the 736-point ethical priority map (23 Asilomar Principles × 32 TDSH parameters)
/// @dev Part of BeTrueCore Developer Package v0.3
/// @author Farman Guliyev (Safarnur) — github.com/Dede-Qorqud/BeTrueCore
///
/// Data protection note. The matrix itself holds no personal data: its 736
/// cells are rules, and they are public by intent. One event declared here
/// reaches the permanent archive — CellTriggered — and it is keyed by session,
/// so it records which ethical questions a collective judgement touched, never
/// whose. What a series of such sets yields when read together was assessed by
/// the lens B4 audit, and the answer is at CellTriggered below: nothing about a
/// person, but a detailed and permanent picture of what a community keeps
/// deliberating about. The full position is in docs/AUTHORITY_CHAIN.md, §11.

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
    /// @dev Three types, three agents of each — nine in all. The bands 1-3,
    ///      4-6 and 7-9 that once stood against these names are the
    ///      participant's VWU status levels and say nothing about what an
    ///      agent does. They are removed rather than renumbered: there was no
    ///      correspondence to correct.
    enum AgentType {
        ANALYST,        // verification · signal authenticity
        STRATEGIST,     // values · ethics · coordination
        SENTINEL        // security · long-term risk
    }

    /// @notice Traffic light verdict, plus the state of having no measurement
    /// @dev UNDETERMINED stands first on purpose. An unset enum field is the
    ///      zero value, so before this change a session carried RED until a
    ///      verdict was computed for it, and an absent measurement was
    ///      indistinguishable from a breached one. It now reads as what it is:
    ///      nothing has been measured yet.
    ///
    ///      Why the state exists (audit lens B8, transfer A-08). A verdict is
    ///      computed from scores the Harmony Agent reports. Where nothing was
    ///      measurable — no choice was made on that side, every entry of the
    ///      report was refused, or every activated cell carries no weight —
    ///      there is nothing to average, and the answer to that is not GREEN.
    ///      Returning GREEN published "no violations found" where the truth was
    ///      "nothing could be read", and lens B1 showed the state is reachable
    ///      by steering the agent with text, not only by accident. The
    ///      architecture records silence as silence for a participant; it
    ///      records an unreadable report the same way, for the same reason — a
    ///      state the reader has to infer from an absence is "no data", and that
    ///      value does not exist anywhere in this protocol.
    ///
    ///      Mirrored in IBeTrueCore.sol, which declares a Verdict of its own.
    ///      The two must carry the same values in the same order; a session's
    ///      verdict crosses from here into the permanent archive through it. A
    ///      session carries two verdicts, one per option.
    enum Verdict {
        UNDETERMINED,   // nothing was measurable · not a judgement
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

    /// @notice Address holding the registrar role of this matrix
    /// @dev Named for how it begins, not for what it is: the deploying address
    ///      receives the role, and from there it passes on — proposeDeployer
    ///      and acceptDeployer below, two steps, through the acting holder
    ///      alone. The position on the temporariness of protocol roles is
    ///      stated once, at the coordinator field in Poll.sol.
    ///
    ///      Correcting what stood here (audit lens B8). This field used to be
    ///      described as holding no authority over participants. It holds two
    ///      powers, and both bear on the verdict rather than on the vote.
    ///      First, populateCells writes the 736 cells, which are the rules a
    ///      verdict is computed against — and it can be called again, so a cell
    ///      is rewritable after the map has been loaded. Second,
    ///      setHarmonyAgent decides which contract may write the audit trail at
    ///      all. Neither touches a participant's weight; together they decide
    ///      what counts as an ethical breach and who may record one. Named here
    ///      rather than softened. The boundary is in docs/AUTHORITY_CHAIN.md,
    ///      §14.
    address public deployer;

    /// @notice Address named to take over the registrar role, not yet in force
    address public pendingDeployer;

    /// @notice Number of times cells have been written
    /// @dev Incremented by populateCells, including a reload that rewrites
    ///      cells already present. The cells are the rules a verdict is
    ///      computed against, so a verdict in the archive means nothing without
    ///      knowing which version of the map produced it. Before lens B8 a
    ///      reload left the same trace as the first load. Loading the full map
    ///      in batches therefore raises this counter once per batch, which is
    ///      correct: each batch is a write.
    uint256 public matrixVersion;

    /// @notice The only contract permitted to write audit events
    /// @dev A contract, not a person: the deployed HarmonyAgent. The pointer
    ///      therefore moves in one step, like the engine pointer in
    ///      VWUEngine.sol — a contract cannot claim a role by calling for
    ///      itself. What the announcement does not establish is which contract
    ///      this is: the event carries two addresses and nothing about their
    ///      code, so pairing this pointer with the agent the community actually
    ///      runs is organisational.
    address public harmonyAgent;

    // ─────────────────────────────────────────────────────────────
    // EVENTS
    // ─────────────────────────────────────────────────────────────

   /// @notice A matrix cell was triggered during a session
    /// @dev Keyed by session, never by participant. The verdict is collective.
    ///      Naming a participant here would publish which ethical question that
    ///      person's judgement touched — a sharper disclosure than any rating.
    ///
    ///      What the series yields, lens B4. One of these events says little.
    ///      The set emitted for one session describes the ethical shape of that
    ///      session across 736 named points; the sets of many sessions describe
    ///      what a community keeps returning to, permanently and in the open.
    ///      That is disclosure about the community, not about a person, and the
    ///      architecture says less about it than it does about participants. In
    ///      a pilot inside one organisation it is that organisation's own map of
    ///      recurring conflict, published to the chain, and whoever adopts the
    ///      protocol should be told so before the first session, not after.
    ///
    ///      Individual records are not reachable from here. The score below is
    ///      produced by agents that read aggregates and never individual
    ///      choices, so the chain from a cell score back to one person is broken
    ///      by construction. What these events add to the series named at
    ///      SessionResult in IBeTrueCore.sol is dimensionality, not a new path.
    event CellTriggered(
        uint256 indexed session_id,
        uint8   asilomar_id,
        uint8   tdsh_id,
        /// @dev Published at a resolution of one unit in a hundred, per cell,
        ///      per session. The verdict beside it is derived from it by
        ///      computeVerdict, a public pure function, so the pair states one
        ///      fact twice — once coarse, once fine. The fine value is what
        ///      lets a third party check the threshold was applied honestly;
        ///      dropping it would cut this event's resolution by some thirty
        ///      times and leave the verdict unverifiable. That is the same trade
        ///      weighed on the aggregate counters. Audit lens B4.
        uint8   ematch_score,    // 0–100 (scaled from 0.0–1.0)
        Verdict verdict
    );

    event MatrixPopulated(uint256 cell_count);

    /// @notice Emitted when the contract permitted to write audit events changes
    /// @dev The power to replace the writer of the audit trail stays where it
    ///      was. What is removed is the silence around using it: a replacement
    ///      becomes visible in the same log it governs.
    event HarmonyAgentChanged(address indexed previous, address indexed current);

    // ─────────────────────────────────────────────────────────────
    // CONSTRUCTOR
    // ─────────────────────────────────────────────────────────────

    constructor() {
        deployer = msg.sender;
    }

    modifier onlyDeployer() {
        require(msg.sender == deployer, "Not deployer");
        _;
    }

    // ─────────────────────────────────────────────────────────────
    // MATRIX POPULATION
    // ─────────────────────────────────────────────────────────────

    /// @notice Connect the HarmonyAgent permitted to write audit events
    /// @dev Intended to be set before the first session, and replaceable at any
    ///      time afterwards by the holder of the registrar role.
    ///      Who may replace it, answered rather than deferred (audit lens B8):
    ///      the acting holder of the registrar role, alone, and that role itself
    ///      passes only through proposeDeployer and acceptDeployer below. There
    ///      is no address above it and no second key beside it. Replacing the
    ///      agent mid-session is not blocked — a verdict must not become
    ///      unrecordable because the pointer moved — and the replacement is
    ///      announced by HarmonyAgentChanged, which is what lets a reader of the
    ///      trail see that the writer changed and when.
    function setHarmonyAgent(address _harmonyAgent) external onlyDeployer {
        require(_harmonyAgent != address(0), "Zero address");
        address previous = harmonyAgent;
        harmonyAgent = _harmonyAgent;
        emit HarmonyAgentChanged(previous, _harmonyAgent);
    }

    /// @notice Populate a batch of cells
    /// @dev Called by deployer to fill the 736-point map
    function populateCells(
        uint8[]     memory asilomar_ids,
        uint8[]     memory tdsh_ids,
        CellState[] memory priorities,
        AgentType[] memory agents
    ) external onlyDeployer {
        require(
            asilomar_ids.length == tdsh_ids.length &&
            tdsh_ids.length == priorities.length &&
            priorities.length == agents.length,
            "Array length mismatch"
        );

        for (uint i = 0; i < asilomar_ids.length; i++) {
            uint16 key = _cellKey(asilomar_ids[i], tdsh_ids[i]);
            cells[key] = EthicalCell({
                asilomar_id: asilomar_ids[i],
                tdsh_id:     tdsh_ids[i],
                priority:    priorities[i],
                agent:       agents[i]
            });
        }

        matrixVersion++;
        emit MatrixPopulated(asilomar_ids.length);
    }

    // ─────────────────────────────────────────────────────────────
    // DEPLOYER HANDOVER
    //
    // Two steps, the same shape as the handovers in Poll.sol,
    // NINNullifierRegistry.sol, VWUEngine.sol and HarmonyAgent.sol: the acting
    // holder names a successor, and the successor takes the role by its own
    // call, which is how it shows it holds the key. Naming a different address
    // replaces an unaccepted proposal; there is no separate cancel.
    //
    // The cost, stated rather than hidden: if the key is lost, the cells can
    // never be corrected and the audit writer can never be repointed. The map
    // and the trail keep working as they stand. No address outside the role is
    // given a way round, because such a way is itself the capture surface.
    //
    // Both events carry the matrix version, so a reader of the trail can tell
    // which loading of the cells was in force when the role changed hands.
    // Audit lens B8.
    // ─────────────────────────────────────────────────────────────

    /// @notice The acting holder named a successor. Nothing has moved yet.
    event DeployerHandoverProposed(address indexed proposed, uint256 matrix_version);

    /// @notice The registrar role passed to its successor
    event DeployerTransferred(
        address indexed previous,
        address indexed current,
        uint256 matrix_version
    );

    /// @notice Name the address that may take over the registrar role
    function proposeDeployer(address proposed) external onlyDeployer {
        require(proposed != address(0), "Zero address");
        require(proposed != deployer, "Already registrar");

        pendingDeployer = proposed;
        emit DeployerHandoverProposed(proposed, matrixVersion);
    }

    /// @notice Take over the registrar role, called by the named address
    function acceptDeployer() external {
        require(msg.sender == pendingDeployer, "Not the proposed registrar");

        address previous = deployer;
        deployer         = msg.sender;
        pendingDeployer  = address(0);

        emit DeployerTransferred(previous, msg.sender, matrixVersion);
    }

    // ─────────────────────────────────────────────────────────────
    // CORE FUNCTIONS
    // ─────────────────────────────────────────────────────────────

    /// @notice Compute the storage key of a cell, rejecting coordinates that
    ///         lie outside the 23x32 matrix
    /// @dev The key a * 100 + t is not injective across the whole uint8 range:
    ///      the pair (a - 1, t + 100) lands on the slot of (a, t) — (1, 132)
    ///      and (2, 32) are the same key, 232. At population that collision
    ///      silently overwrites a cell. On a read it is worse: the caller draws
    ///      the weight of one cell while naming another, and the name is what
    ///      the audit trail keeps. Every path that names a cell by its
    ///      coordinates goes through here — population, the three getters, and
    ///      the bound in triggerCell. One path does not: the getter the
    ///      compiler generates for the public cells mapping takes a raw key. It
    ///      can read a slot no valid pair maps to, and returns an empty cell
    ///      when it does. It cannot create a collision, because nothing writes
    ///      except through this function.
    function _cellKey(
        uint8 asilomar_id,
        uint8 tdsh_id
    ) internal pure returns (uint16) {
        require(
            asilomar_id >= 1 && asilomar_id <= 23,
            "Asilomar id out of range"
        );
        require(
            tdsh_id >= 1 && tdsh_id <= 32,
            "TDSH id out of range"
        );
        return uint16(asilomar_id) * 100 + uint16(tdsh_id);
    }

    /// @notice Get the weight of a cell (0–3)
    /// @param asilomar_id Asilomar Principle ID (1–23)
    /// @param tdsh_id TDSH Parameter ID (1–32)
    /// @return weight 0=SUPERPOSITION, 1=MEDIUM, 2=HIGH, 3=CRITICAL
    function getCellWeight(
        uint8 asilomar_id,
        uint8 tdsh_id
    ) public view returns (uint8) {
        CellState priority = cells[_cellKey(asilomar_id, tdsh_id)].priority;

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
        return cells[_cellKey(asilomar_id, tdsh_id)].agent;
    }

    /// @notice Get full cell data
    function getCell(
        uint8 asilomar_id,
        uint8 tdsh_id
    ) external view returns (EthicalCell memory) {
        return cells[_cellKey(asilomar_id, tdsh_id)];
    }

    /// @notice Emit CellTriggered event
    /// @dev Only the connected HarmonyAgent may write to the audit trail.
    ///      Without this restriction any address could forge audit events.
    function triggerCell(
        uint256 session_id,
        uint8 asilomar_id,
        uint8 tdsh_id,
        uint8 ematch_score
    ) external {
        require(msg.sender == harmonyAgent, "Only HarmonyAgent");

        // Bound the coordinates before they enter the permanent archive:
        // without this the trail can be made to name a cell that does not
        // exist. The returned key is not needed here; the call is made for the
        // check. The score is bounded for the same reason — this event
        // documents a resolution of one unit in a hundred, and uint8 admits 255.
        _cellKey(asilomar_id, tdsh_id);
        require(ematch_score <= 100, "Ematch score out of range");

        Verdict verdict = computeVerdict(ematch_score);
        emit CellTriggered(session_id, asilomar_id, tdsh_id, ematch_score, verdict);
    }
}