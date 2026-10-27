// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IBeTrueCore.sol";
import "./EthicalMatrix.sol";
import "./HarmonyAgent.sol";
import "./VWUEngine.sol";

/// @title BeTrueCoreCore
/// @notice Main implementation contract for BeTrueCore
/// @dev Part of BeTrueCore Developer Package v0.3
/// @author Farman Guliyev (Safarnur) — github.com/Dede-Qorqud/BeTrueCore
///
/// Architecture: L0 (NIN-code ZK) → L1 (ZK + anti-collusion protocol) → L2 (Optimism) →
///               L3 (Lit Protocol) → L4 (Celestia DA) → L5 (AI agents, read-only)
///
/// Constitutional principle: AI is the notary. The human is the author.
/// Paradigm: secret citizen — transparent decision
///
/// Pre-block visibility (audit lens B5)
/// Every argument this contract receives is visible on the peer-to-peer
/// network before it reaches a block, and stays in the chain's history
/// afterwards: the commitment in register(), the nullifier and the
/// encrypted choice in submitChoice(), and in applySessionParticipation()
/// the full list of commitments together with the per-person session data
/// aligned to it. Removing a field from an event does not remove it from
/// the call. 
/// Stage A closed the log; it did not close the input.
/// See AUTHORITY_CHAIN.md §11.
///
/// No participant-authored text reaches this contract (audit lens B1)
/// A session is opened with a hash of the dilemma, and a choice arrives
/// encrypted and binary. The prompts, the agenda they are selected into, and
/// the text of the dilemma itself exist only off-chain — which is also where
/// the L5 observation agents read them. The consequence is worth stating in
/// both directions. Nothing in this file can be steered by text, so no change
/// here closes prompt injection; and nothing in this file can be relied on to
/// close it either, so treating the absence of a surface as a defence would be
/// a claim the code does not support. What the chain contributes is the hash:
/// it fixes which text was in force. The boundary itself is in
/// docs/AUTHORITY_CHAIN.md, §13.

contract BeTrueCoreCore is IBeTrueCore {

    // ─────────────────────────────────────────────────────────────
    // STATE
    // ─────────────────────────────────────────────────────────────

    /// @notice Participant registry
    mapping(bytes32 => Participant) private participants;

    /// @notice Session registry
    mapping(uint256 => Session) private sessions;

    /// @notice Session results (after coordinator finalization)
    mapping(uint256 => SessionResult) private sessionResults;

    /// @notice ZK nullifier registry — prevents double-voting
    mapping(bytes32 => bool) private usedNullifiers;

    /// @notice Session counter
    uint256 private sessionCounter;

    /// @notice Connected contracts
    EthicalMatrix public ethicalMatrix;
    HarmonyAgent  public harmonyAgent;
    VWUEngine     public vwuEngine;

    /// @notice Anti-collusion coordinator address (only can finalize sessions)
    address public maciCoordinator;

    /// @notice Address named to take over the coordinator role, not yet in force
    address public pendingCoordinator;

    // No role stands above participants in this contract: sessions are
    // opened and finalized by the coordinator, and the coordinator is the
    // community itself.
    //
    // How the role is held and passed. The deployment address picks
    // maciCoordinator once, in the constructor. From there the role passes
    // only through the acting coordinator, in two steps, under COORDINATOR
    // HANDOVER below; the deploying address has no further say and cannot take
    // the role back. The cost of that choice is stated plainly: if the
    // coordinator's key is lost, nothing in this file can move the role, and
    // reaching it means redeploying this contract. The role is meant to be
    // temporary and to end with the community governing through the protocol
    // itself — the position on the three trials is stated once, at the
    // coordinator field in Poll.sol.
    //
    // A handover mid-session. Nothing here stops one, and finalizeSession
    // checks the current holder only, so sessions opened by the previous
    // coordinator are finalized by the next one. This is deliberate — a session
    // must not become unfinalizable because the role moved — and it is what the
    // session counter in CoordinatorTransferred records: the event fixes where
    // in the run of sessions the role changed hands, so a reader of the archive
    // can tell which sessions were opened under which holder. The counter is
    // not a session id and does not say that a session was open at that moment.
    //
    // Where the leverage actually is (audit lens B8). Not in this role as such.
    // The coordinator alone opens sessions and alone calls
    // applySessionParticipation with a roster and the deltas against it,
    // neither of them proved to the contract, so crediting a participant nobody
    // chose costs one coordinator call (lens B7). Those deltas are the weight
    // itself: the formula runs off-chain, before the call, and what crosses
    // into the chain is its result. Capturing the role therefore yields the
    // power to set what any participation was worth — a stronger power than
    // opening sessions, and one no check in this file constrains. The boundary
    // is in docs/AUTHORITY_CHAIN.md, §14.

    /// @notice Number of successful register() calls — aggregate only
    /// @dev Not the number of people, and not the size of the community.
    ///      register() verifies no proof and restricts no caller, so this
    ///      counts entries that anyone could have created, one per call.
    ///      It is also unrelated to the Merkle root held in
    ///      NINNullifierRegistry.sol on L1: that root fixes the set of
    ///      commitments, this counter is incremented here on L2, and no
    ///      function in either contract compares the two. A reader who takes
    ///      getParticipantCount() for the roster is reading a number that
    ///      rests on the same trust as the root — the party that computes it.
    uint256 private participantCount;

    /// @notice Σ VWU of every registered participant, kept in step with the
    ///         engine — aggregate only
    /// @dev Why it is here and not in VWUEngine. A session fixes its roster
    ///      when it opens, and the silent row of the Panorama is that roster
    ///      less the two sides, so the roster has to be a figure the contract
    ///      holds rather than one supplied with the result. The count was
    ///      already here; the weight was not, and the engine exposes no sum —
    ///      balances are private there and getStatusDistribution gives levels,
    ///      not weight. This contract already receives both parts: the
    ///      non-burnable base at registration and every applied delta
    ///      afterwards, the engine's own bounded figure. So it keeps the sum
    ///      itself instead of opening a new aggregate on the engine.
    ///      This publishes nothing new. The three sums of any finalized
    ///      session already add up to it, and the registration count is
    ///      emitted on every registration. What it adds is a fixed point to
    ///      check a result against.
    uint256 private rosterWeightTotal;

    // ─────────────────────────────────────────────────────────────
    // AGGREGATE EVENTS — no event field names a participant
    //
    // That is a statement about the fields. It is not a statement about what
    // the chain discloses, and the three events below disclose more together
    // than any of them does alone. Two are emitted inside the participant's
    // own transaction; the third is emitted inside a call whose arguments
    // list every commitment credited. Counting them per session yields
    // quantities none of them carries. See the pre-block note at the head of
    // this file and the per-event notes below. Audit lens B4.
    // ─────────────────────────────────────────────────────────────

    /// @notice The registry grew by one. No commitment, no address.
    /// @dev The field is a count of entries, not of people — see the note at
    ///      participantCount. Published as a count of participants it would
    ///      overstate what the protocol establishes, and the same caution
    ///      applies to getParticipantCount() in the view section and to every
    ///      text of the project that calls the roster closed.
    event RegistryGrew(uint256 participant_count);

    /// @notice A session was opened. The dilemma is named by its hash.
    /// @dev Adds nothing that was not already public: the hash arrives as an
    ///      argument of openSession and is readable afterwards through
    ///      getSession. What it adds is durability of the anchor. The text
    ///      behind this hash is what the L5 observation agents read, and a
    ///      report about a session can be checked afterwards only against the
    ///      text that was actually in force. An archive assembled from events
    ///      was carrying the end of a session and not its beginning.
    ///      Audit lens B1.
    event SessionOpened(
        uint256 indexed session_id,
        bytes32 indexed dilemma_hash,
        uint256 start_time,
        uint256 end_time
    );

    /// @notice A choice was recorded in a session. No participant named.
    /// @dev Indexed by session, so the events of one session are collected by
    ///      a single query, and their number is the count of responses in that
    ///      session. Each is emitted in the sender's own transaction, so the
    ///      same query also yields the set of addresses that responded.
    ///      Neither the count nor the set is a field of this event; both
    ///      follow from it being emitted once per response.
    event ChoiceRecorded(uint256 indexed session_id);

    /// @notice Session participation was applied to ratings.
    /// @dev participants_counted is the size of the roster credited for the
    ///      session. A record exists for every fixed participant, silence
    ///      included, so this number is the roster, not the turnout. The count
    ///      of ChoiceRecorded events for the same session is the turnout.
    ///      Published side by side under one session id, the two numbers
    ///      differ by the participants who stayed silent. That difference is
    ///      not a leak: both counts are published by design in the
    ///      transparency report of a session, and the number who stayed
    ///      silent is therefore knowable by design too. Silence is a recorded
    ///      state, not missing data, and a sovereign signal rather than an
    ///      absence to be hidden. What stays closed is which participant was
    ///      silent — the count says how many, never who.
    ///      The call that emits this also lists, in its arguments, the
    ///      commitments credited; the query above yields the addresses that
    ///      responded. For one session those are two sets of the same people,
    ///      and over a run of sessions their intersections pair an address
    ///      with a commitment, though the two are never published together.
    ///      Stage A removed the derivation of a commitment from an address;
    ///      this is the same correspondence re-formed from published sets.
    ///      Audit lens B4. See AUTHORITY_CHAIN.md §11.
    event ParticipationApplied(uint256 indexed session_id, uint256 participants_counted);

    /// @notice A session was finalized; the result carries the Panorama's rows
    ///         and the verdict of each side.
    /// @dev Declared here because this is where aggregate events live. The
    ///      result now carries six figures rather than two sums — a count and a
    ///      sum of weight for Option A, for Option B and for silence — and two
    ///      verdicts, one per option. What those figures disclose, and why they
    ///      are not removable, is stated in full at their declaration in
    ///      IBeTrueCore.sol: publishing them is what the Panorama shows and
    ///      what makes the result recomputable by a third party, which is the
    ///      requirement they exist for. The counts narrow the reconstruction
    ///      further than the sums did alone; that is recorded there, in one
    ///      place rather than two.
    event SessionFinalized(uint256 indexed session_id, SessionResult result);

    // ─────────────────────────────────────────────────────────────
    // VWU THRESHOLDS FOR STATUS LEVELS
    //
    // The second copy. VWUEngine.sol declares the same six names with the same
    // values and runs its own _computeStatus over them, and nothing compares
    // the two: the engine's statusCount and the status written into a
    // participant's record here are computed by separate copies of one table.
    // The rule is stated elsewhere in this project — two places holding one
    // threshold is how they drift apart (HarmonyAgent.sol, at the CRITICAL
    // band) — and here it is not kept. Until one file reads the other, a
    // threshold changes in both or in neither. The values themselves are
    // illustrative; the operative ones follow the master document, and the
    // relation they must keep is stated at the engine's copy — the cap stands
    // above the highest threshold, never on it.
    // ─────────────────────────────────────────────────────────────

    uint256 constant VWU_SOLO       = 0;      // Copper   — entry
    uint256 constant VWU_SELFLY     = 100;    // Bronze   — 1.00 VWU
    uint256 constant VWU_UNIVERSAL  = 300;    // Titanium — 3.00 VWU
    uint256 constant VWU_HONORIS    = 700;    // Silver   — 7.00 VWU
    uint256 constant VWU_LUMINARE   = 1500;   // Gold     — 15.00 VWU
    uint256 constant VWU_VERITAS_ZK = 3000;   // Platinum — 30.00 VWU

    // ─────────────────────────────────────────────────────────────
    // CONSTRUCTOR
    // ─────────────────────────────────────────────────────────────

    constructor(
        address _maciCoordinator,
        address _ethicalMatrix,
        address _harmonyAgent,
        address _vwuEngine
    ) {
        maciCoordinator  = _maciCoordinator;
        ethicalMatrix    = EthicalMatrix(_ethicalMatrix);
        harmonyAgent     = HarmonyAgent(_harmonyAgent);
        vwuEngine        = VWUEngine(_vwuEngine);
    }

    // ─────────────────────────────────────────────────────────────
    // MODIFIERS
    // ─────────────────────────────────────────────────────────────

       modifier onlyCoordinator() {
        require(msg.sender == maciCoordinator, "Only anti-collusion coordinator");
        _;
    }

    modifier sessionActive(uint256 session_id) {
        require(isSessionActive(session_id), "Session not active");
        _;
    }

    modifier sessionExists(uint256 session_id) {
        require(sessions[session_id].start_time > 0, "Session does not exist");
        _;
    }

    // ─────────────────────────────────────────────────────────────
    // COORDINATOR HANDOVER
    //
    // Two steps on purpose: the acting coordinator names a successor, and the
    // successor takes the role by its own call, which is how it shows it holds
    // the key. A one-step setter would hand the role to a mistyped address with
    // no way back, and the role cannot be recovered by anyone — not by the
    // deploying address, not by participants. Naming a different address
    // replaces an unaccepted proposal; there is no separate cancel.
    //
    // Both events name both addresses, so a handover is never silent in the
    // archive. Power stays with the role; what is removed is the silence.
    // Audit lens B8.
    // ─────────────────────────────────────────────────────────────

    /// @notice The acting coordinator named a successor. Nothing has moved yet.
    event CoordinatorHandoverProposed(
        address indexed proposed,
        uint256 session_counter
    );

    /// @notice The role passed. session_counter fixes where in the run of
    ///         sessions it happened; it is not a session id.
    event CoordinatorTransferred(
        address indexed previous,
        address indexed current,
        uint256 session_counter
    );

    /// @notice Name the address that may take over the coordinator role
    function proposeCoordinator(address proposed) external onlyCoordinator {
        require(proposed != address(0), "Zero address");
        require(proposed != maciCoordinator, "Already coordinator");

        pendingCoordinator = proposed;
        emit CoordinatorHandoverProposed(proposed, sessionCounter);
    }

    /// @notice Take over the coordinator role, called by the named address
    function acceptCoordinator() external {
        require(msg.sender == pendingCoordinator, "Not the proposed coordinator");

        address previous   = maciCoordinator;
        maciCoordinator    = msg.sender;
        pendingCoordinator = address(0);

        emit CoordinatorTransferred(previous, msg.sender, sessionCounter);
    }

    // ─────────────────────────────────────────────────────────────
    // PARTICIPANT FUNCTIONS
    // ─────────────────────────────────────────────────────────────

    /// @notice Register a new participant
    /// @dev Requires L0 NIN-code ZK-commitment + L1 ZK proof
    ///      bytes32 identity_commitment is not an address, and it is not
    ///      hidden either: it is a public argument of this call, bound to
    ///      the sender for anyone watching the network, from the moment of
    ///      registration and before any block holds it.
    ///      Consequence: the registry is keyed by the commitment, so the
    ///      first check below answers "is C registered?" to anyone who
    ///      simulates this call locally — no transaction, no trace. The
    ///      read path closed in stage A is reachable this way. Closing it
    ///      needs the registration proof verified on-chain (lens B7); it
    ///      is not closed by anything in this file.
    ///      Registration is a single operation across both contracts: the
    ///      participant is initialized in VWUEngine and receives the
    ///      non-burnable base score — «Varlıq özü imzadır».
    ///
    ///      Cost of one extra participant (lens B7). Zero. This function is
    ///      external and unguarded: any address may call it with any 32-byte
    ///      value, the proof argument is accepted and never read, and the
    ///      number of calls is bounded by nothing. This is the widest of the
    ///      three doors into the roster — the Phase 2 ceremony of the trusted
    ///      setup and updateMerkleRoot in NINNullifierRegistry.sol are each
    ///      reachable by one party, this one by every address. The three are
    ///      listed together in circuits/COMPILE.md, because closing one and
    ///      leaving the others open changes nothing. Nothing between a caller
    ///      and an extra entry costs
    ///      work, stake, a vouch, a synchronous ceremony, or a test telling a
    ///      human from a machine. Cheaper imitation of a human therefore does
    ///      not change this price: there is no test here for an agent to pass.
    ///      What the price actually rests on lies outside this contract and
    ///      outside cryptography — the client that is supposed to check the
    ///      number at the e-government gateway, and whoever computes the tree
    ///      root. Both guarantees are organisational, and they are to be
    ///      named as organisational everywhere Sybil-resistance is claimed
    ///      for L0. See the corresponding block in NINCommitment.circom.
    function register(
        bytes32 identity_commitment,
        bytes calldata zk_proof
    ) external override {
        require(
            participants[identity_commitment].identity_commitment == bytes32(0),
            "Already registered"
        );

        // ZK proof verification would be performed here
        // via Circom verifier contract (external dependency)
        // _verifyRegistrationProof(identity_commitment, zk_proof);

        address participant_address =
            address(uint160(uint256(identity_commitment)));

        vwuEngine.initializeParticipant(participant_address);

        uint256 base = vwuEngine.VWU_BASE();

        participants[identity_commitment] = Participant({
            identity_commitment: identity_commitment,
            vwu:                 base,
            status:              _computeStatus(base),
            session_count:       0,
            last_session:        0
        });

        participantCount++;
        rosterWeightTotal += base;
        emit RegistryGrew(participantCount);
    }

    /// @notice Submit a choice within an active session
    /// @dev Read the name of this function against what the code does: on
    ///      THIS path a choice cannot be updated. The first call marks the
    ///      nullifier used, a second call carrying it is refused by the guard
    ///      below, and no other nullifier exists for the same session — it is
    ///      derived from the participant's secret and the session id, so it is
    ///      fixed. Key rotation lives in Poll.publishMessage, which keys its
    ///      per-participant message budget by the sending address and admits
    ///      many messages; this contract has no such path.
    ///      Consequence under lens B6: a participant coerced into sending here
    ///      cannot overwrite the choice afterwards, and the unprovability that
    ///      re-choice buys does not apply. The two nullifier registries are to
    ///      be unified after stage B (see the note below); whatever unifies
    ///      them has to decide which of the two behaviours this path keeps.
    ///      Receipt-freeness: encrypted_choice is not written to storage.
    ///      It is still a public argument: visible on the network before
    ///      the block and kept in the chain's history. What is protected
    ///      is the content of the choice, by encryption — not the fact or
    ///      the moment of sending it. Nor is it protected from a coercer who
    ///      holds the key material: that case is stated in full at
    ///      RECEIPT-FREENESS GUARANTEE — AND ITS LIMIT in Poll.sol.
    ///      Open, not fixed here: the nullifier is marked used without any
    ///      check — no proof, no registration, no link to the sender. An
    ///      observer who sees a nullifier before it is mined can spend it
    ///      first and lock its owner out of the session. Cheaper here than at
    ///      joinPoll in Poll.sol: there a copied proof still has to verify,
    ///      here nothing is verified at all, so any address can burn any
    ///      nullifier it has seen. Same class as the second finding of A-13;
    ///      it is the two nullifier registries that have to be unified, which
    ///      is a decision after stage B.
    ///      Direction chosen 14.10.2026: the ZK proof of prior join, stated
    ///      once at the coordinator field in Poll.sol. Whatever unifies the
    ///      two registries has to carry that proof here as well — otherwise
    ///      one door is shut and this one stays open.
    function submitChoice(
        uint256 session_id,
        bytes calldata encrypted_choice,
        bytes32 zk_nullifier
    ) external override sessionActive(session_id) {
        require(!usedNullifiers[zk_nullifier], "Nullifier already used");

        // Mark nullifier as used — prevents double-voting
        usedNullifiers[zk_nullifier] = true;

        // encrypted_choice is forwarded to anti-collusion coordinator off-chain
        // Only one choice per nullifier reaches the coordinator from this
        // path: the guard above admits a single call. The invalidation of
        // intermediate choices by key rotation happens in Poll.publishMessage
        // and does not describe this function.

        // No identity field is emitted. This keeps the log from being an
        // index of who took part — it does not make participation unseen.
        // The call arrives from the participant's own address, the
        // nullifier is in its arguments, and the set of commitments for
        // the session is published later by applySessionParticipation.
        emit ChoiceRecorded(session_id);
    }

    // ─────────────────────────────────────────────────────────────
    // SESSION FUNCTIONS
    // ─────────────────────────────────────────────────────────────

    /// @notice Open a new session with a dilemma
    /// @dev Behind onlyCoordinator, matching openPoll in Poll.sol. It used to
    ///      sit behind the deployment role, which put the timing of sessions —
    ///      and through timing, the agenda — in the hands of whoever deployed
    ///      the contract. Opening at L1 and opening at L2 are the same act and
    ///      cannot stand behind two different roles.
    ///
    ///      What the hash is not tied to (audit lens B1). Two links are
    ///      missing, and both bear on the text the L5 agents read. First:
    ///      nothing here shows that this dilemma came from the agenda the
    ///      community selected. The coordinator supplies a hash and the
    ///      contract records it, while the selection of the three agenda items
    ///      happens off-chain and leaves no trace this contract can check.
    ///      Second: openPoll in Poll.sol takes a dilemma hash of its own, and
    ///      no function in either contract compares the two, so L1 and L2 can
    ///      hold different hashes for what is meant to be one session. Until
    ///      both links exist, the hash fixes which text this contract was told
    ///      about, not which text the community chose.
    function openSession(
        bytes32 dilemma_hash,
        uint256 duration_seconds
    ) external override onlyCoordinator returns (uint256 session_id) {
        sessionCounter++;
        session_id = sessionCounter;

        sessions[session_id] = Session({
            dilemma_hash: dilemma_hash,
            start_time:   block.timestamp,
            end_time:     block.timestamp + duration_seconds,
            // The roster is taken here and never moves again. Whoever
            // registers while this session is open is registered, and joins
            // from the next one: this session closed its roster before they
            // arrived. The application says so at the moment of registration
            // rather than leaving it to be noticed — admission is confirmed
            // when the current session ends. That is the admission rule of
            // this architecture made visible to the participant: the set is
            // closed before mutual observation begins.
            //
            // What this snapshot assumes, and what nothing here enforces.
            // roster_weight is the live sum at the moment of opening, and
            // applySessionParticipation moves that same sum when it credits a
            // session. Nothing in this contract requires the previous session
            // to have been credited before a new one opens, and nothing stops
            // two sessions being open at once. Open a session before the
            // previous one is credited and this snapshot stops matching the
            // balances the engine holds: finalizeSession will then refuse
            // every honest result for it, because the check compares the three
            // sums against a figure the crediting has since moved past, and
            // the session cannot be closed at all. Sessions are therefore to
            // be run one at a time — opened only after the previous one has
            // been finalized and credited. That is an operating rule, not a
            // guarantee of this file. Making it a guarantee needs a per-session
            // "credited" flag this contract does not keep, and that is a
            // revision rather than a correction.
            roster_count:  participantCount,
            roster_weight: rosterWeightTotal,
            finalized:    false,
            // Not GREEN at opening. A session that has not been judged yet
            // carries the state of having no measurement, on both sides: GREEN
            // here meant a freshly opened session already read as "integrity
            // confirmed" to anyone looking at it before finalization.
            verdict_option_a: Verdict.UNDETERMINED,
            verdict_option_b: Verdict.UNDETERMINED
        });

        emit SessionOpened(
            session_id,
            dilemma_hash,
            block.timestamp,
            block.timestamp + duration_seconds
        );
    }

    /// @notice Finalize session after time lock (coordinator only)
    /// @dev Coordinator publishes ZK proof of correct counting simultaneously
    ///      Coordinator can deny service but cannot falsify results
    ///      The result published by this call carries the weight sums per
    ///      option. Those are not counting queries: one participant moves a
    ///      sum by their own weight, not by one, so they are finer-grained
    ///      than anything else this contract publishes. What a run of exact
    ///      sums over known rosters yields is stated at SessionResult in
    ///      IBeTrueCore.sol, in one place rather than two.
    ///
    ///      Reveal is not simultaneous (lens B5). The result arrives in the
    ///      arguments of this call and is visible on the network before any
    ///      block holds it, so whoever watches the network knows the outcome
    ///      before it reaches the participants. The window is small and
    ///      carries no leverage inside the protocol: the session is already
    ///      closed, choices are locked, and nothing here can be changed in
    ///      response. What it does cost is the strict form of the claim —
    ///      "the result opens to everyone at one moment" is not exact, and
    ///      the Panorama is the moment of showing, not the moment of
    ///      becoming knowable.
    function finalizeSession(
        uint256 session_id,
        SessionResult calldata result
    ) external override onlyCoordinator sessionExists(session_id) {
        require(!sessions[session_id].finalized, "Already finalized");
        require(
            block.timestamp >= sessions[session_id].end_time,
            "Time lock not reached"
        );

        // The three rows must account for the roster fixed at open — by
        // people and by weight alike. Silence covers those who entered and
        // chose neither option and those who did not take part at all, so the
        // three rows cover everyone fixed for this session, and nothing is
        // left over. This is arithmetic over figures the contract already
        // holds: it proves nothing about who stood where, and a result built
        // on false rows still passes. What it does catch is a result that
        // drops a participant or adds one who was not in the roster — which
        // until now passed unnoticed.
        require(
            result.count_option_a + result.count_option_b + result.count_silent
                == sessions[session_id].roster_count,
            "Rows do not account for the roster"
        );
        require(
            result.total_weight_a + result.total_weight_b + result.total_weight_silent
                == sessions[session_id].roster_weight,
            "Weights do not account for the roster"
        );

        // Store result
        sessionResults[session_id] = result;
        sessions[session_id].finalized = true;
        sessions[session_id].verdict_option_a = result.verdict_option_a;
        sessions[session_id].verdict_option_b = result.verdict_option_b;

        emit SessionFinalized(session_id, result);
    }

    /// @notice Apply session contributions to participant ratings
    /// @dev Called by the protocol after finalizeSession, once per session.
    ///      The aggregated result records the collective decision; this call
    ///      credits what each person contributed to reaching it.
    ///
    ///      What this call publishes, and what it no longer does (lens B5).
    ///      Its arguments are public: visible on the network before the block,
    ///      kept in the chain's history. They carry the commitments taking
    ///      part and, against each, one signed number — the contribution
    ///      already computed. They used to carry the inputs of that
    ///      computation instead: completed steps, prompt flags, and the
    ///      support level recorded for each of the three agenda dilemmas. That
    ///      is a per-person record of how someone responded, and publishing it
    ///      gave away after the reveal exactly what L0 and L1 protect before
    ///      it — without anyone having to ask the participant for anything.
    ///      The computation now runs in the protocol; its result crosses here.
    ///      What remains visible is that a given commitment was credited, and
    ///      by how much. Closing that is the same Phase 2 item as plaintext-
    ///      free storage of the balance. See AUTHORITY_CHAIN.md §11.
    ///
    ///      Bearing on L5 (audit lens B1). The specification of the agent
    ///      layer states that agents read aggregates and never individual
    ///      records. The events of this contract keep to that; the arguments
    ///      of this call do not, since they align one commitment with one
    ///      number per person and stay in the chain's history like any call.
    ///      The statement therefore holds or fails at the L5-to-L4 gateway,
    ///      according to whether what it exposes is assembled from events
    ///      alone or from transactions. That is a property of the gateway and
    ///      not of this file, and it is recorded as an open item rather than
    ///      answered here.
    function applySessionParticipation(
        uint256            session_id,
        bytes32[] calldata identity_commitments,
        int256[]  calldata deltas
    ) external onlyCoordinator sessionExists(session_id) {
        require(sessions[session_id].finalized, "Session not finalized");

        uint256 n = identity_commitments.length;
        require(deltas.length == n, "Length mismatch");

        // Every participant fixed for this session gets a record — those who
        // chose, those who entered and stayed silent, and those who did not
        // take part at all. Silence is a recorded state, not an absence, and
        // responsibility rests on that: the one who stayed silent answers too.
        // A short list would leave some of them with no record and turn
        // silence back into missing data, which this architecture does not
        // produce anywhere.
        //
        // What this check does not reach: that the commitments in the list are
        // the ones fixed for the session rather than others of the same
        // number. That is the set-equality primitive named as not established
        // at L1 — the count is what can be checked here, and it is checked.
        //
        // The consequence for whoever calls this: a session is credited in one
        // call, whole. Splitting it into batches is not possible while this
        // check stands, and at pilot size — 50 to 100 participants — one call
        // carries it. When a community outgrows a single call, the check moves
        // to a per-session counter that closes the session once the roster is
        // covered; that is a later revision, not a reason to leave the gap
        // open now.
        require(
            n == sessions[session_id].roster_count,
            "List does not cover the roster"
        );

        for (uint256 i = 0; i < n; i++) {
            _updateParticipantVWU(identity_commitments[i], deltas[i]);
        }

        emit ParticipationApplied(session_id, n);
    }

    // ─────────────────────────────────────────────────────────────
    // VWU INTERNAL UPDATE
    // ─────────────────────────────────────────────────────────────

    /// @notice Update VWU for a participant after session finalization
    /// @dev Called internally after coordinator result is published
    ///      The full VWU formula (including non-linear factor) is protected
    ///      in the BeTrueCore master document (OpenTimestamps SHA-256)
    function _updateParticipantVWU(
        bytes32 identity_commitment,
        int256  session_delta
    ) internal {
        // The roster handed to applySessionParticipation is not proved to
        // this contract, so an unregistered commitment must not be credited
        // here. Without this check the mapping creates a record whose
        // identity_commitment field stays zero, which register() then reads
        // as "not registered" — so the entry collects a balance, and a later
        // register() call on the same commitment overwrites it and resets
        // session_count. Crediting someone nobody chose would cost one
        // coordinator call (lens B7).
        require(
            participants[identity_commitment].identity_commitment != bytes32(0),
            "Participant not registered"
        );

        // Hand the computed contribution to VWUEngine, which bounds it and
        // keeps the balance. The formula itself is not here and not there:
        // it runs in the protocol, before this call — see the note on
        // applySessionParticipation above.
        VWUEngine.SessionResult memory sr = VWUEngine.SessionResult({
            participant:       address(uint160(uint256(identity_commitment))),
            delta:             session_delta,
            session_timestamp: block.timestamp
        });

        int256 delta = vwuEngine.updateVWU(sr);

        // Update local participant record.
        // VWUEngine reports the delta of the session it was given; accumulated
        // balances are readable by their owner only.
        //
        // The cast below is explicit and therefore unchecked even under
        // 0.8.x: uint256(negative) wraps instead of reverting, so a delta
        // larger than the balance would produce a figure on the order of
        // 2^256 rather than a floor. The non-burnable floor is VWUEngine's
        // to enforce and its value does not belong here; this contract
        // checks only that the result did not go below zero, which reveals
        // no threshold.
        uint256 current = participants[identity_commitment].vwu;
        int256  signed_new = int256(current) + delta;
        require(signed_new >= 0, "VWU below zero");
        uint256 new_vwu = uint256(signed_new);

        // Keep the roster weight in step. The figure added is the engine's
        // own applied delta, already bounded by the non-burnable floor and the
        // cap, so this sum never diverges from the balances the engine holds.
        if (delta >= 0) {
            rosterWeightTotal += uint256(delta);
        } else {
            rosterWeightTotal -= uint256(-delta);
        }

        participants[identity_commitment].vwu = new_vwu;
        participants[identity_commitment].status = _computeStatus(new_vwu);
        participants[identity_commitment].session_count++;
        participants[identity_commitment].last_session = block.timestamp;
    }

    /// @notice Compute status level from VWU balance
    function _computeStatus(uint256 vwu_balance) internal pure returns (Status) {
        if (vwu_balance >= VWU_VERITAS_ZK) return Status.VERITAS_ZK;
        if (vwu_balance >= VWU_LUMINARE)   return Status.LUMINARE;
        if (vwu_balance >= VWU_HONORIS)    return Status.HONORIS;
        if (vwu_balance >= VWU_UNIVERSAL)  return Status.UNIVERSAL;
        if (vwu_balance >= VWU_SELFLY)     return Status.SELFLY;
        return Status.SOLO;
    }

    // ─────────────────────────────────────────────────────────────
    // VIEW FUNCTIONS

    function getParticipantCount() external view override returns (uint256) {
        return participantCount;
    }

    /// @notice Get a session by id
    function getSession(
        uint256 session_id
    ) external view override returns (Session memory) {
        return sessions[session_id];
    }

    /// @dev A second channel to the data of SessionFinalized, live rather than
    ///      historical: a reader who keeps no logs still obtains the weight
    ///      sums of every finalized session by iterating session ids, and
    ///      getSessionCount below gives the range to iterate.
    function getSessionResult(
        uint256 session_id
    ) external view override returns (SessionResult memory) {
        require(sessions[session_id].finalized, "Session not finalized");
        return sessionResults[session_id];
    }

    function isSessionActive(
        uint256 session_id
    ) public view override returns (bool) {
        Session memory s = sessions[session_id];
        return (
            s.start_time > 0 &&
            !s.finalized &&
            block.timestamp >= s.start_time &&
            block.timestamp < s.end_time
        );
    }

    function getSessionCount() external view returns (uint256) {
        return sessionCounter;
    }
}