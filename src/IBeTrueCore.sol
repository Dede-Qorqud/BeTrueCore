// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IBeTrueCore
/// @notice Core interface for BeTrueCore — cryptographic infrastructure for
///         sovereign collective decision-making
/// @dev Part of BeTrueCore Developer Package v0.3
/// @author Farman Guliyev (Safarnur) — github.com/Dede-Qorqud/BeTrueCore
///
/// Constitutional principle: AI is the notary. The human is the author.
/// Paradigm: secret citizen — transparent decision
///
/// Data protection note. Two of the values declared here are pseudonyms in the
/// legal sense, not an absence of identifiers: the identity commitment passed
/// to register, and the session-bound nullifier passed to submitChoice. Each
/// travels in calldata and stays in the chain's history, and a pseudonym that
/// distinguishes one participant within a context is an identifier under EU
/// data protection law. Nothing declared here carries a name, an address or a
/// demographic attribute. A third value belongs beside the two named above,
/// found by the lens B4 audit: the per-commitment contribution published by
/// applySessionParticipation. It is an attribute attached to a pseudonym, and
/// its series gives the weight of each participant at every point in time —
/// see the note at SessionResult below. The full position — what the
/// architecture claims and what it does not — is in docs/AUTHORITY_CHAIN.md,
/// §11.

interface IBeTrueCore {

    // ─────────────────────────────────────────────────────────────
    // ENUMS
    // ─────────────────────────────────────────────────────────────

    /// @notice Participant status levels (VWU-based progression)
    /// @dev Status reflects accumulated activity and utility of judgement.
    ///      It does not express the ethical quality of any decision: ethical
    ///      assessment belongs to the 736-point map and the Harmony Agent
    ///      verdict, never to VWU.
    enum Status {
        SOLO,       // Copper   — entry level
        SELFLY,     // Bronze   — individual signal established
        UNIVERSAL,  // Titanium — consistent participation
        HONORIS,    // Silver   — sustained utility of judgement
        LUMINARE,   // Gold     — community anchor
        VERITAS_ZK  // Platinum — zero-knowledge verified standing
    }

    /// @notice Binary choice for each dilemma (time-locked until session close)
    /// @dev SILENT replaces the former NONE, which meant "has not chosen yet"
    ///      and so published "no data" — a value this architecture does not
    ///      produce anywhere. Silence is a choice and a sovereign signal: the
    ///      participant who answers nothing has answered. It is not an
    ///      abstention and not a third option — the dilemma stays binary, and
    ///      there is no third button in the application.
    ///      SILENT stands first, so that an unset field reads as silence
    ///      rather than as a missing value. That is correct rather than
    ///      convenient: before the first choice, and for anyone who never
    ///      makes one, silence is the true state.
    ///      Weight is attached to it like any other state. A participant of
    ///      high standing may stay silent, and the weight that stayed silent
    ///      is what the Panorama publishes beside the count: a measure of how
    ///      much the dilemma mattered to the community, not of the people who
    ///      withheld. That weight is added to neither side and carries no
    ///      colour, ever.
    ///      Not referenced by any struct or function in this interface, nor by
    ///      any contract of the package: a choice travels encrypted, as bytes,
    ///      and the three-way split is published as counts and sums in
    ///      SessionResult. The enum is kept as the vocabulary those counts
    ///      refer to, and because the off-chain tally works in these terms.
    ///      One caution about that correspondence. The silent row of
    ///      SessionResult is wider than this value: SILENT is the state of a
    ///      participant who entered and chose neither option, while
    ///      count_silent also covers everyone in the roster who did not enter
    ///      at all, and they made no choice of any kind. The row is the roster
    ///      less the two sides — never a count of SILENT values.
    enum Choice {
        SILENT,     // recorded silence — the voice of silence, never "no data"
        OPTION_A,   // first option
        OPTION_B    // second option
    }

    /// @notice Traffic light verdict from Harmony Agent, plus the state of
    ///         having no measurement
    /// @dev UNDETERMINED stands first on purpose. An unset enum field is the
    ///      zero value, so before this change a session carried RED until a
    ///      verdict was computed for it, and an absent measurement was
    ///      indistinguishable from a breached one.
    ///      Why the state exists: a verdict rests on what the Harmony Agent
    ///      could read. Where nothing was measurable — no choice was made at
    ///      all, or every entry of the report was refused — the answer is not
    ///      GREEN. Returning GREEN published "no violations found" where the
    ///      truth was "nothing could be read".
    ///      Declared identically in EthicalMatrix.sol. The two must carry the
    ///      same values in the same order: a session's verdict crosses from
    ///      there into the permanent archive through this interface.
    ///      One session carries two verdicts, not one — see Session and
    ///      SessionResult below.
    enum Verdict {
        UNDETERMINED, // nothing was measurable · not a judgement
        RED,          // Ematch < 0.4 · integrity threshold breached
        YELLOW,       // Ematch 0.4–0.7 · partial degradation
        GREEN         // Ematch >= 0.7 · integrity confirmed
    }

    // ─────────────────────────────────────────────────────────────
    // STRUCTS
    // ─────────────────────────────────────────────────────────────

    /// @notice Participant record
    /// @dev Keyed by a bytes32 commitment rather than an address. That keeps the
    ///      record free of a wallet identifier; it does not make the record
    ///      anonymous. Five attributes held against one person form a record in
    ///      the legal sense, and the more attributes a record carries, the more
    ///      effective re-identification becomes against it. Whether this
    ///      contract should hold the rating and the status at all — they are
    ///      held primarily in VWUEngine — remains an open design question.
    ///      The lens B4 review adds a second ground to that question: with the
    ///      personal getters removed from VWUEngine and getParticipant removed
    ///      from here, nothing outside the contract reads this mirror, and
    ///      inside it two of the five fields are read while three are not.
    ///      identity_commitment is the registration check, read in register and
    ///      again in _updateParticipantVWU; vwu is read to compute the new
    ///      balance. status, session_count and last_session are written on
    ///      every applied session and read by nothing, here or anywhere else in
    ///      the package — three attributes per person held at a storage cost
    ///      that buys nothing today.
    struct Participant {
        bytes32 identity_commitment;  // ZK-commitment to verified state identity (NIN-code)
        uint256 vwu;                  // Vote Weight Unit (scaled ×100)
        Status  status;               // Current status level
        uint256 session_count;        // Total sessions participated
        uint256 last_session;         // Timestamp of last session
    }

    /// @notice Session record — the dilemma, its time window, the roster fixed
    ///         for it, and its verdicts
    /// @dev Two verdicts, one per option, because the traffic light is applied
    ///      to each side of the dilemma separately — Option A and Option B
    ///      alike. Equal application means one measure — the same 736-point map
    ///      and the same thresholds — not one colour. On the Panorama the sides
    ///      are read as majority and minority, and that is where those words
    ///      belong: a numerical majority is not thereby right, and a small
    ///      minority is not thereby wrong.
    ///      They are keyed by option, never by majority and minority. Nothing
    ///      in this package tells a contract which side was larger, and that is
    ///      deliberate: a verdict computed without knowing the sizes cannot be
    ///      softened for the larger side. Which option held the majority
    ///      follows from the counts in SessionResult, where the Panorama reads
    ///      it. Silence receives no verdict at all.
    ///
    ///      The roster is fixed when the session opens and does not move
    ///      afterwards. Both figures below are written by openSession and never
    ///      again. They are what makes the Panorama checkable: silence covers
    ///      those who entered and chose neither option and those who did not
    ///      take part at all, so the silent row is the roster less the two
    ///      sides, and without a fixed roster it could not be computed — nor
    ///      could a reader verify that the three rows account for everyone.
    ///
    ///      Whoever registers while a session is open is registered, and joins
    ///      from the next session: this one closed its roster before they
    ///      arrived. The application says so at the moment of registration
    ///      rather than leaving it to be noticed — admission is confirmed when
    ///      the current session ends. That is the admission rule of this
    ///      architecture made visible to the participant: the set is closed
    ///      before mutual observation begins, which is the part of completeness
    ///      this protocol can hold.
    ///
    ///      These two figures publish nothing new. The number of registered
    ///      participants is already emitted on every registration, and the
    ///      weight of the roster follows from the three sums of any session's
    ///      result. What they add is a fixed point to check those against.
    struct Session {
        bytes32 dilemma_hash;         // 32-byte commitment to the dilemma text; see AUTHORITY_CHAIN.md §13
        uint256 start_time;           // Session open timestamp
        uint256 end_time;             // Time lock — after this, choices are final
        uint256 roster_count;         // Participants registered when the session opened
        uint256 roster_weight;        // Σ VWU of that roster, at that moment
        bool    finalized;            // Whether anti-collusion coordinator has published the result
        Verdict verdict_option_a;     // Harmony Agent verdict for Option A
        Verdict verdict_option_b;     // Harmony Agent verdict for Option B
    }

    /// @notice Session result after coordinator finalization — the Panorama,
    ///         as numbers
    /// @dev What the six figures disclose, stated in full here because this is
    ///      where they are declared. Audit lenses B4 and B8.
    ///
    ///      What they are for. The Panorama carries the roster total at its
    ///      head — all participants, as a count and as a sum of weight — and
    ///      three rows below it: Option A, Option B, silence. Each of the three
    ///      carries a count and, beside it, a sum of weight. The head is not
    ///      stored: the roster is the three counts added together and the
    ///      weight of the roster is the three sums added together, and a figure
    ///      that can be derived is not kept twice.
    ///
    ///      What counts as silence, and why it is wider than it looks. Silence
    ///      covers two kinds of participant at once: those who entered the
    ///      session and chose neither option, and those who did not take part
    ///      in this session at all. Both are in the fixed roster, so both are
    ///      in this row — which is why count_silent cannot be summed from the
    ///      messages submitted. It is the roster less the two sides, and it
    ///      therefore depends on the roster being fixed for the session and
    ///      known to whoever computes this result.
    ///
    ///      Silence carries weight like any other state — a participant of
    ///      high standing may stay silent — and that weight is added to neither
    ///      side and carries no verdict, ever. It measures the dilemma rather
    ///      than the people: how much of the community's weight the question
    ///      failed to move.
    ///
    ///      The sums are the sharper of the two kinds. One participant moves a
    ///      count by one; they move a sum by their own weight. A sum is
    ///      therefore finer-grained than anything else the architecture
    ///      publishes, and its sensitivity is the largest weight one
    ///      participant can hold.
    ///
    ///      Individual weights are not secret from the chain. Every participant
    ///      starts at the non-burnable base, and every later change is published
    ///      against their commitment by applySessionParticipation, one signed
    ///      number at a time. A reader who follows that call holds the current
    ///      weight of every commitment, and the roster of each session besides.
    ///      Nothing has to be collected from anyone's device: the figures are
    ///      in the arguments of ordinary calls, readable by anyone, and what is
    ///      published is the change per person, so no subtraction is needed.
    ///
    ///      Given the roster, the individual weights and these sums, the
    ///      three-way split of a session — who stood with Option A, who with
    ///      Option B, who stayed silent — is a subset-sum question over known
    ///      numbers. The counts added in this revision narrow it: a reader now
    ///      knows not only how much weight each side carried but out of how
    ///      many people it was composed, and candidate assignments that match a
    ///      sum but not a count fall away. In a large community the question
    ///      need not resolve uniquely; in a small one it usually does, and
    ///      across a run of sessions the consistent assignment narrows to one.
    ///      What the chain never supplies is whose commitment is whose: there
    ///      is no name anywhere in it, and no list of communities or of people.
    ///      Where participants already know one another, that link comes from
    ///      outside the protocol — which is why the exposure is slight while a
    ///      session is held among acquaintances and becomes the live question
    ///      once the roster grows beyond them.
    ///
    ///      What that costs is the confidentiality of the choice itself — the
    ///      property the time lock, the key rotation and the encrypted ballot
    ///      are built to hold. It is not broken cryptographically. It is
    ///      recomputed from figures published in the open, each harmless alone.
    ///      Dwork and Roth, The Algorithmic Foundations of Differential Privacy,
    ///      2014, definition 8.1 and theorem 8.1: a mechanism that answers
    ///      exactly, with no error, permits reconstruction of the underlying
    ///      records.
    ///
    ///      Editing this struct fixes none of it, and the figures are not
    ///      removable: they are what the Panorama shows and what lets a third
    ///      party recompute the result. What closes the gap is a proof of the
    ///      tally that does not publish the figures it is computed over — the
    ///      same class of missing primitive as the one named at L1, carried as
    ///      an open item rather than answered here. See
    ///      docs/AUTHORITY_CHAIN.md §11.
    struct SessionResult {
        uint256 session_id;
        uint256 count_option_a;       // participants choosing OPTION_A
        uint256 total_weight_a;       // Σ VWU of participants choosing OPTION_A
        uint256 count_option_b;       // participants choosing OPTION_B
        uint256 total_weight_b;       // Σ VWU of participants choosing OPTION_B
        uint256 count_silent;         // participants who stayed silent
        uint256 total_weight_silent;  // Σ VWU of those who stayed silent
        bytes32 zk_proof_hash;        // Hash of ZK correctness proof from coordinator
        Verdict verdict_option_a;     // Harmony Agent verdict for Option A
        Verdict verdict_option_b;     // Harmony Agent verdict for Option B
    }

    // ─────────────────────────────────────────────────────────────
    // EVENTS
    // ─────────────────────────────────────────────────────────────

    // Participant-level events removed: a log entry naming a participant turns
    // the chain into a searchable record of who took part and when.
    // Aggregate events are declared in BeTrueCoreCore.sol.
    

    // EthicalVerdictIssued removed: nothing emitted it. HarmonyAgent.sol
    // publishes the same pair — session id and verdict, with the aggregate
    // score beside them — through VerdictComputed. The lens B4 note that stood
    // here has moved there with the figure it describes.

    // ─────────────────────────────────────────────────────────────
    // PARTICIPANT FUNCTIONS
    // ─────────────────────────────────────────────────────────────

    /// @notice Register a new participant (requires L0 NIN-code ZK-commitment + L1 ZK proof)
    /// @param identity_commitment ZK commitment to verified state identity (NIN-code)
    /// @param zk_proof ZK-SNARK proof of valid registration
    function register(
        bytes32 identity_commitment,
        bytes calldata zk_proof
    ) external;

    /// @notice Submit a choice for a session. On this path it cannot be updated.
    /// @dev The implementation says the same thing at its own declaration, and
    ///      the interface is not to widen it. In BeTrueCoreCore the first call
    ///      marks the nullifier used and a second call carrying it is refused;
    ///      no other nullifier exists for the same session, since it is derived
    ///      from the participant's secret and the session id. Key rotation —
    ///      many messages, only the last one counted — lives in
    ///      Poll.publishMessage, which keys its per-participant budget by the
    ///      sending address. The two nullifier registries are to be unified
    ///      after stage B, and whatever unifies them decides which of the two
    ///      behaviours this path keeps.
    /// @param session_id Active session ID
    /// @param encrypted_choice Encrypted choice. Receipt-freeness holds inside
    ///        the protocol perimeter, for a participant who holds their own
    ///        key; it does not hold against observation at the moment of
    ///        choosing, nor against a key held by someone else
    ///        (docs/AUTHORITY_CHAIN.md §12)
    /// @param zk_nullifier ZK nullifier preventing a second entry in this session
    function submitChoice(
        uint256 session_id,
        bytes calldata encrypted_choice,
        bytes32 zk_nullifier
    ) external;

    // ─────────────────────────────────────────────────────────────
    // SESSION FUNCTIONS
    // ─────────────────────────────────────────────────────────────

    /// @notice Open a new session with a dilemma
    /// @dev Fixes the roster for this session: the number of registered
    ///      participants and the sum of their weight are written into the
    ///      Session record here and never again. Registrations that arrive
    ///      while the session is open take effect from the next one.
    /// @param dilemma_hash 32-byte commitment to the dilemma text (AUTHORITY_CHAIN.md §13)
    /// @param duration_seconds Session duration before time lock
    function openSession(
        bytes32 dilemma_hash,
        uint256 duration_seconds
    ) external returns (uint256 session_id);

    /// @notice Finalize a session after time lock (coordinator only)
    /// @dev The three rows of the result must account for the roster fixed at
    ///      open: the counts add up to roster_count and the sums to
    ///      roster_weight. The contract checks this before it accepts the
    ///      result. The check is arithmetic over figures it already holds and
    ///      proves nothing about who stood where — but a result that drops a
    ///      participant, or adds one who was not in the roster, no longer
    ///      passes unnoticed.
    /// @param session_id Session to finalize
    /// @param result Aggregated result with ZK correctness proof
    function finalizeSession(
        uint256 session_id,
        SessionResult calldata result
    ) external;

    // ─────────────────────────────────────────────────────────────
    // VIEW FUNCTIONS
    // ─────────────────────────────────────────────────────────────

    /// @notice Number of registered participants — aggregate only
    /// @dev No per-participant read exists on this contract. A caller cannot
    ///      prove ownership of a commitment on-chain without a ZK proof, so a
    ///      gated personal getter is not possible here. Nor do personal reads
    ///      live in VWUEngine any longer: its caller-keyed getters were removed
    ///      by the lens B4 revision, because the record they served is keyed by
    ///      an address derived from the commitment, to which no one holds a key.
    ///      A participant sees their own colours and points in the application.
    ///      On-chain personal reading returns in Phase 2, served by a proof of
    ///      ownership rather than by a caller address.
    function getParticipantCount() external view returns (uint256);

    /// @notice Get session data
    function getSession(
        uint256 session_id
    ) external view returns (Session memory);

    /// @notice Get session result (after finalization)
    function getSessionResult(
        uint256 session_id
    ) external view returns (SessionResult memory);

    /// @notice Check if a session is within its time window
    function isSessionActive(
        uint256 session_id
    ) external view returns (bool);
}