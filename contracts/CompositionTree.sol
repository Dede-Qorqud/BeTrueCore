// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
 * ═════════════════════════════════════════════════════════════════════════════
 * BeTrueCore — CompositionTree.sol
 * On-chain composition tree of one community
 *
 * Author:  Farman Guliyev (Safarnur)
 * ORCID:   0009-0004-4841-594X
 * GitHub:  github.com/Dede-Qorqud/BeTrueCore
 * Version: 0.1 — MVP Contract
 * ═════════════════════════════════════════════════════════════════════════════
 *
 * PURPOSE
 * ───────
 * One community, one tree. A leaf appears when a person joins THIS community;
 * the root bears witness to the whole composition at once and names nobody.
 *
 * The root is NOT submitted to this contract. It is computed here, from the
 * leaves handed in, and that is the whole point of the design: a root carrying
 * a leaf nobody chose cannot be passed in, because no root can be passed in at
 * all. Anyone reading the chain recomputes every transition from the calls that
 * made it. There is therefore no role answerable for the root's correctness —
 * and none is to be added. A role that holds the root forms a shell with legal
 * personality inside the island, exactly where the architecture refuses one.
 *
 * What the registrar is, and what it is not. Inserting a leaf is allowed to one
 * immutable address, the contract that verified the registration proof behind
 * that leaf. It is trusted for LIVENESS and not for correctness: it may fail to
 * hand in a batch, which is a denial of service, and it cannot hand in a root,
 * a wrong transition, or a leaf twice at the same index. The address is fixed
 * in the constructor and has no setter, for the reason given at the registration
 * verifier in BeTrueCoreCore.sol: a setter would be a standing power able to
 * point this tree at a contract that inserts anything.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * INTEGRATION WITH BeTrueCore ARCHITECTURE:
 *
 *   L0 (Identity)  — NIN confirmed at the e-government gateway, in the client.
 *                    Nothing cryptographic ties that confirmation to a leaf
 *                    here, and that is deliberate: were the leaf bound to it,
 *                    the party issuing numbers could link a person to a record.
 *                    One entry per registered secret, not one per citizen.
 *   L1 (Proofs)    ← THIS CONTRACT — the composition this community decides by
 *   L2 (Execution) — BeTrueCoreCore.sol verifies the registration proof and is
 *                    the registrar here; openSession takes the root of this
 *                    tree as the session's snapshot and keeps it for ever
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * TWO THINGS THE CALLER MUST DO, AND WHY
 *
 *   Hand leaves in a BATCH, not one per call. A separate call per entrant
 *   hands an observer the order of entries into the community. The batch is a
 *   privacy requirement first and an economy second — though it is both: a
 *   lone leaf costs about twenty times the marginal cost of a leaf inside a
 *   batch.
 *
 *   Hand them in on a CADENCE, not at a count. The tree is written once a day
 *   with whatever has accumulated, however little. Waiting for a count makes a
 *   newcomer wait for strangers to arrive; a day bounds that wait. A batch of
 *   one is acceptable: the entrant's own address never appears here, because
 *   the registrar sends the call, and from the next session the person is one
 *   of the whole roster and indistinguishable inside it.
 *
 *   What neither closes, stated rather than left out: one person entering two
 *   communities on the same day is linkable by that date. Correlation by
 *   network features — timing, address, traffic pattern — lies at the network
 *   level and is not closed by this contract.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * LEVELS IS NOT A LIMIT ON THE COMMUNITY
 *
 *   LEVELS = 20 is the capacity of a data structure: 1 048 576 places. No upper
 *   and no lower limit on the size of a community is set here, and none is to
 *   be added — a limit would turn size from a reading into a norm, and then a
 *   community that fell short of it would count as having failed. Size is
 *   published because it is a reading.
 *
 *   Three numbers in this project happen to share digits and mean different
 *   things. They are not to be read into one another:
 *     LEVELS = 20        — places in this tree
 *     seven steps        — one participant's session: one prompt, three agenda
 *                          choices, three dilemma choices
 *     max_messages = 20  — re-submissions allowed to one participant in one
 *                          session (PollConfig in IBeTrueCoreAntiCollusion.sol)
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * WHAT THIS CONTRACT PUBLISHES, READ AGAINST ITS NEIGHBOURS (audit lens B4)
 *
 *   root and nextIndex are public, and nextIndex is the size of the community.
 *   That figure is published by design. LeavesInserted carries how many leaves
 *   a day brought, so the series of those events is the community's growth
 *   curve, day by day. LeafRemoved carries that someone left and when. Neither
 *   event names anyone, and no call here carries a participant's address.
 *   The exact weight of a departing participant is published elsewhere, by
 *   arithmetic rather than by this contract: the roster weight sum falls by
 *   precisely that amount. See IBeTrueCore.sol, SessionResult.
 * ═════════════════════════════════════════════════════════════════════════════
 */

/// @notice Poseidon hash of two field elements, as generated by circomlibjs.
/// @dev The same hash the circuits use. A different implementation of the same
///      hash is fine; a different hash is not — the roots would stop matching
///      the proofs that circuits/NINIdentityProof.circom builds.
interface IPoseidon2 {
    function poseidon(uint256[2] calldata input) external pure returns (uint256);
}

/// @title CompositionTree
/// @notice The composition of one community: a leaf per person who joined.
contract CompositionTree {

    // ══════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Depth of the tree. Capacity, not a limit on the community.
    uint256 public constant LEVELS = 20;

    /// @notice Field order of BN254, the curve the circuits are built on.
    uint256 internal constant SNARK_SCALAR_FIELD =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    // ══════════════════════════════════════════════════════════════════════
    // STATE
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Poseidon(2), fixed at deployment. No setter: see the header.
    IPoseidon2 public immutable hasher;

    /// @notice The only address allowed to insert and remove leaves — the
    ///         contract that verified the registration proof behind a leaf.
    ///         Fixed at deployment. No setter: see the header.
    address public immutable registrar;

    /// @notice Current root of the composition.
    uint256 public root;

    /// @notice Number of leaves inserted so far — the size of the community.
    uint256 public nextIndex;

    /// @dev The left child awaiting a right sibling, per level, on the frontier.
    uint256[20] internal filledSubtrees;

    /// @dev The root of an empty subtree, per level.
    uint256[20] internal zeros;

    // ══════════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════════

    /// @notice A batch was written into the tree.
    /// @dev WHY THE LEAVES THEMSELVES ARE HERE. Without them the log says a
    ///      root moved and not what moved it, so recomputing the tree means
    ///      reading the calldata of every registration on an archive node.
    ///      The leaves arrive in an internal call and are in no transaction's
    ///      calldata at all. An archive built from events — which is what L4
    ///      keeps, what L5 reads and what a third party is handed — could
    ///      therefore show every root transition and prove none of them.
    ///      With the batch in the log, anyone holding the log alone can
    ///      rebuild the tree and arrive at new_root or fail to.
    ///
    ///      It discloses nothing that was not public. Each leaf is the
    ///      commitment its owner passed to register, in the calldata of their
    ///      own transaction, visible on the network before it was mined. What
    ///      changes is that reading the set no longer needs an archive node.
    ///
    ///      Why this does not undo the batching. register emits no
    ///      commitment, deliberately, so nothing here ties a leaf to the
    ///      address that registered it; the batch is what hides that
    ///      correspondence and the batch is unchanged. A batch of one would
    ///      show one person entering alone — which is why the core writes on
    ///      a cadence and not per entrant. Audit lens B4 and B5.
    /// @param count       How many leaves this batch carried.
    /// @param first_index Index of the first leaf of the batch.
    /// @param new_root    The root after the batch.
    /// @param leaves      The batch itself, in the order it went in.
    event LeavesInserted(
        uint256 count,
        uint256 first_index,
        uint256 new_root,
        uint256[] leaves
    );

    /// @notice A leaf was zeroed — a participant left the community.
    /// @param leaf_index Position that was zeroed.
    /// @param new_root   The root after the removal.
    event LeafRemoved(uint256 leaf_index, uint256 new_root);

    // ══════════════════════════════════════════════════════════════════════
    // ERRORS
    // ══════════════════════════════════════════════════════════════════════

    error OnlyRegistrar();
    error EmptyBatch();
    error TreeFull();
    error LeafOutOfField(uint256 leaf);
    error IndexNotWritten(uint256 leaf_index);
    error PathDoesNotMatchRoot();
    error ZeroAddress();

    // ══════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ══════════════════════════════════════════════════════════════════════

    /// @param _hasher    Poseidon(2) contract.
    /// @param _registrar The contract allowed to write here.
    /// @dev Both are refused as the zero address at deployment rather than at
    ///      the first call: a tree wired to nothing is not a tree, and finding
    ///      that out on the first registration is finding it out too late.
    constructor(IPoseidon2 _hasher, address _registrar) {
        if (address(_hasher) == address(0)) revert ZeroAddress();
        if (_registrar == address(0)) revert ZeroAddress();

        hasher    = _hasher;
        registrar = _registrar;

        uint256 z = 0;
        for (uint256 i = 0; i < LEVELS; i++) {
            zeros[i]          = z;
            filledSubtrees[i] = z;
            z = _hasher.poseidon([z, z]);
        }
        root = z;
    }

    modifier onlyRegistrar() {
        if (msg.sender != registrar) revert OnlyRegistrar();
        _;
    }

    // ══════════════════════════════════════════════════════════════════════
    // CORE — INSERT A BATCH
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Write a day's leaves into the tree and recompute the root.
    /// @dev The batch is walked LEVEL BY LEVEL, once, over the affected range —
    ///      about 2N + LEVELS hashes. Inserting the same leaves one at a time
    ///      yields the SAME root at about N × LEVELS hashes, measured at seven
    ///      times the cost for a batch of ten. The loop is therefore not an
    ///      equivalent shortcut to be restored later; it is the same answer
    ///      bought dearly.
    /// @param leaves Commitments to insert, in order.
    function insertBatch(uint256[] calldata leaves) external onlyRegistrar {
        uint256 n = leaves.length;
        if (n == 0) revert EmptyBatch();

        uint256 start = nextIndex;
        if (start + n > (1 << LEVELS)) revert TreeFull();

        uint256[] memory cur = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            if (leaves[i] >= SNARK_SCALAR_FIELD) revert LeafOutOfField(leaves[i]);
            cur[i] = leaves[i];
        }

        uint256 lastIdx  = start + n - 1;
        uint256 curStart = start;

        for (uint256 lvl = 0; lvl < LEVELS; lvl++) {
            // Read before writing: the frontier value of this level is the left
            // sibling of the batch when the batch begins on an odd index.
            uint256 oldFilled = filledSubtrees[lvl];
            uint256 curEnd    = curStart + cur.length - 1;

            // What filledSubtrees must hold at this level once the batch is in:
            // the EVEN node of the frontier pair — the one a later insert on an
            // odd index will read as its left sibling. Taking the frontier node
            // itself is wrong whenever the frontier lands on an odd index: the
            // node completed beside it, inside this very batch, is the one that
            // will be needed, and it is not the last leaf's. That was the first
            // version of this loop, and it gave a correct root for a batch into
            // an empty tree and a wrong one for every batch after it.
            // Where that even node lies left of the batch, it was completed
            // earlier and filledSubtrees already holds it — leave it alone.
            uint256 evenAt = (lastIdx >> lvl) & ~uint256(1);
            if (evenAt >= curStart && evenAt <= curEnd) {
                filledSubtrees[lvl] = cur[evenAt - curStart];
            }

            uint256 nextStart = curStart >> 1;
            uint256 m = (curEnd >> 1) - nextStart + 1;
            uint256[] memory nxt = new uint256[](m);

            for (uint256 k = 0; k < m; k++) {
                uint256 li = (nextStart + k) * 2;
                uint256 ri = li + 1;
                uint256 lv = (li >= curStart && li <= curEnd)
                    ? cur[li - curStart]
                    : oldFilled;
                uint256 rv = (ri >= curStart && ri <= curEnd)
                    ? cur[ri - curStart]
                    : zeros[lvl];
                nxt[k] = hasher.poseidon([lv, rv]);
            }

            cur      = nxt;
            curStart = nextStart;
        }

        root      = cur[0];
        nextIndex = start + n;

        emit LeavesInserted(n, start, root, leaves);
    }

    // ══════════════════════════════════════════════════════════════════════
    // CORE — REMOVE A LEAF
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Zero the leaf of a participant who left, and recompute the root.
    /// @dev Deletion works forwards only. The archive is append-only, weight is
    ///      never subtracted from archived sums, and the root of every past
    ///      session stays in that session's snapshot — so a past Panorama goes
    ///      on bearing witness to the composition as it stood when that session
    ///      opened. What this call changes is the composition from the next
    ///      session on.
    ///
    ///      The caller supplies the path, and the path is checked against the
    ///      current root before anything is written. The frontier is kept in
    ///      step: where the recomputed node of this path is also the frontier's
    ///      left child at that level, filledSubtrees is refreshed, or the next
    ///      batch would build on a value that no longer exists in the tree.
    /// @param leaf_index Position of the leaf.
    /// @param leaf       Its current value.
    /// @param siblings   Merkle path, bottom to top.
    function removeLeaf(
        uint256 leaf_index,
        uint256 leaf,
        uint256[20] calldata siblings
    ) external onlyRegistrar {
        if (leaf_index >= nextIndex) revert IndexNotWritten(leaf_index);

        // Check the path against the root that stands now.
        uint256 cur = leaf;
        uint256 j   = leaf_index;
        for (uint256 i = 0; i < LEVELS; i++) {
            cur = (j & 1 == 0)
                ? hasher.poseidon([cur, siblings[i]])
                : hasher.poseidon([siblings[i], cur]);
            j >>= 1;
        }
        if (cur != root) revert PathDoesNotMatchRoot();

        // Recompute with the leaf zeroed, keeping the frontier in step.
        uint256 frontier = nextIndex - 1;
        cur = 0;
        j   = leaf_index;
        for (uint256 i = 0; i < LEVELS; i++) {
            // Same invariant as insertBatch: filledSubtrees holds the even node
            // of the frontier pair. If the node this path passes through at
            // this level is that node, its value has just changed and the entry
            // is refreshed — otherwise the next batch builds on a value that no
            // longer exists in the tree.
            if ((leaf_index >> i) == ((frontier >> i) & ~uint256(1))) {
                filledSubtrees[i] = cur;
            }
            cur = (j & 1 == 0)
                ? hasher.poseidon([cur, siblings[i]])
                : hasher.poseidon([siblings[i], cur]);
            j >>= 1;
        }

        root = cur;

        emit LeafRemoved(leaf_index, root);
    }

    // ══════════════════════════════════════════════════════════════════════
    // VIEW
    // ══════════════════════════════════════════════════════════════════════

    /// @notice The root a session takes as its snapshot at opening.
    /// @dev openSession keeps the value it reads here for ever, and proofs for
    ///      that session are checked against the kept value rather than against
    ///      this one. That is what lets the tree go on growing while a session
    ///      runs, and it is why registration no longer has to be frozen for the
    ///      duration of a session.
    function currentRoot() external view returns (uint256) {
        return root;
    }

    /// @notice How many people are in the community.
    /// @dev A reading, not a norm — see the header.
    function size() external view returns (uint256) {
        return nextIndex;
    }
}
