// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/CompositionTree.sol";
import "./PoseidonT3Bytecode.sol";

/// @title CompositionTreeTest — the tree against a real Poseidon
/// @notice What test/CompositionTreeStub.sol says it does not check
/// @dev The other two suites wire a stand-in, because their promises turn on
///      no hash. These are the promises that turn on nothing else: that the
///      root is the Merkle root of what went in, that a second batch does not
///      corrupt it, that only the registrar may write, and that a removal
///      leaves a tree a third party can still recompute.
///
///      WHERE THE EXPECTED ROOTS COME FROM, and why that matters more than
///      their values. Each was computed by circomlibjs building the tree from
///      the leaves, outside this repository and by an implementation that
///      shares no line with the contract. A test that compared the contract
///      with a second walk written by the same hand would check that the hand
///      was consistent, not that it was right: that is exactly how the batch
///      bug below survived its first measurement. The recipe is at the head of
///      PoseidonT3Bytecode.sol, and the leaves here are 1..18 so the whole
///      fixture can be rebuilt in a few lines.
///
///      THE BUG THESE NUMBERS EXIST TO CATCH. Refreshing the level frontier
///      from the LAST leaf of a batch gives a correct root for the first batch
///      into an empty tree and a wrong root for every batch after it, because
///      the node that the next batch needs as its left sibling is completed
///      inside the current one and is not the last leaf's node. One batch into
///      an empty tree therefore proves nothing. The second and third batches
///      here are the test.
contract CompositionTreeTest is Test {

    CompositionTree internal tree;
    address internal hasher;

    address internal registrar = address(0xBEEF);
    address internal stranger  = address(0xCAFE);

    // ─────────────────────────────────────────────────────────────
    // FIXTURES — circomlibjs, outside this repository
    // ─────────────────────────────────────────────────────────────

    /// @dev poseidon([1, 2]). A swapped bytecode blob fails on this line
    ///      rather than silently changing every root below.
    uint256 constant POSEIDON_1_2 =
        7853200120776062878684798364095072458815029376092732009249414926327459813530;

    /// @dev Root of a tree of 20 empty levels
    uint256 constant EMPTY_ROOT =
        15019797232609675441998260052101280400536945603062888308240081994073687793470;

    /// @dev After leaves 1..10
    uint256 constant ROOT_AFTER_A =
        17598744648445052066954988150684674064428269269096810531281798236310219109835;

    /// @dev After leaves 1..17. The second batch: seven leaves onto ten.
    uint256 constant ROOT_AFTER_B =
        15476429621913486726206171743013241386972512402061793315937402598134254881373;

    /// @dev After leaves 1..18. A batch of one, landing on an odd index.
    uint256 constant ROOT_AFTER_C =
        18742262321132897736880487980207713705375203780787876805286261428789714797192;

    /// @dev After leaf index 3 is zeroed in that same tree
    uint256 constant ROOT_AFTER_REMOVAL =
        3012231890516583272720113283439547877888475384687197053805633741434657973767;

    /// @dev Merkle path of leaf index 3, bottom to top, in the tree of 1..18
    function _pathForIndex3() internal pure returns (uint256[20] memory s) {
        s[0]  = 3;
        s[1]  = 7853200120776062878684798364095072458815029376092732009249414926327459813530;
        s[2]  = 14693904821945502268578313651525098196765636411922213115469821563817117273617;
        s[3]  = 14888979664003708571660847718791296103112999134302095820460705268575071148941;
        s[4]  = 628550342749357383637787782676762726059871885664988991336526143200528285371;
        s[5]  = 19712377064642672829441595136074946683621277828620209496774504837737984048981;
        s[6]  = 20775607673010627194014556968476266066927294572720319469184847051418138353016;
        s[7]  = 3396914609616007258851405644437304192397291162432396347162513310381425243293;
        s[8]  = 21551820661461729022865262380882070649935529853313286572328683688269863701601;
        s[9]  = 6573136701248752079028194407151022595060682063033565181951145966236778420039;
        s[10] = 12413880268183407374852357075976609371175688755676981206018884971008854919922;
        s[11] = 14271763308400718165336499097156975241954733520325982997864342600795471836726;
        s[12] = 20066985985293572387227381049700832219069292839614107140851619262827735677018;
        s[13] = 9394776414966240069580838672673694685292165040808226440647796406499139370960;
        s[14] = 11331146992410411304059858900317123658895005918277453009197229807340014528524;
        s[15] = 15819538789928229930262697811477882737253464456578333862691129291651619515538;
        s[16] = 19217088683336594659449020493828377907203207941212636669271704950158751593251;
        s[17] = 21035245323335827719745544373081896983162834604456827698288649288827293579666;
        s[18] = 6939770416153240137322503476966641397417391950902474480970945462551409848591;
        s[19] = 10941962436777715901943463195175331263348098796018438960955633645115732864202;
    }

    // ─────────────────────────────────────────────────────────────
    // SETUP
    // ─────────────────────────────────────────────────────────────

    function setUp() public {
        hasher = PoseidonT3Bytecode.deploy();
        tree   = new CompositionTree(IPoseidon2(hasher), registrar);
    }

    /// @dev Leaves lo..hi inclusive, as a batch
    function _range(uint256 lo, uint256 hi) internal pure returns (uint256[] memory out) {
        out = new uint256[](hi - lo + 1);
        for (uint256 i = 0; i < out.length; i++) out[i] = lo + i;
    }

    function _insert(uint256 lo, uint256 hi) internal {
        vm.prank(registrar);
        tree.insertBatch(_range(lo, hi));
    }

    // ─────────────────────────────────────────────────────────────
    // THE HASHER IS THE ONE THE CIRCUITS USE
    // ─────────────────────────────────────────────────────────────

    /// Everything below is a statement about Poseidon. If the deployed blob
    /// were some other hash, every root would differ and the cause would be
    /// hard to see. This fails first, and says so.
    function test_the_hasher_is_the_poseidon_the_circuits_use() public view {
        assertEq(
            IPoseidon2(hasher).poseidon([uint256(1), uint256(2)]),
            POSEIDON_1_2,
            "the deployed bytecode is not circomlib's two-input Poseidon"
        );
    }

    // ─────────────────────────────────────────────────────────────
    // THE ROOT IS THE MERKLE ROOT OF WHAT WENT IN
    // ─────────────────────────────────────────────────────────────

    /// An empty tree already has a root, laid out by the constructor. A tree
    /// that answered zero here would let a session open against nothing.
    function test_an_empty_tree_has_the_empty_root() public view {
        assertEq(tree.currentRoot(), EMPTY_ROOT, "empty root");
        assertEq(tree.size(), 0, "and holds nothing");
    }

    function test_the_root_after_one_batch_is_the_merkle_root_of_it() public {
        _insert(1, 10);
        assertEq(tree.currentRoot(), ROOT_AFTER_A, "root after ten leaves");
        assertEq(tree.size(), 10, "ten places taken");
    }

    /// THE ONE THAT MATTERS. A second batch onto a tree that already holds
    /// leaves is where the frontier is easy to get wrong, and where a wrong
    /// implementation still passes the test above.
    function test_a_second_batch_builds_on_the_first() public {
        _insert(1, 10);
        _insert(11, 17);
        assertEq(tree.currentRoot(), ROOT_AFTER_B, "root after seven more");
        assertEq(tree.size(), 17, "seventeen places taken");
    }

    /// A batch of one, landing on an odd index, which is the other side of the
    /// same frontier question.
    function test_a_batch_of_one_on_an_odd_index() public {
        _insert(1, 10);
        _insert(11, 17);
        _insert(18, 18);
        assertEq(tree.currentRoot(), ROOT_AFTER_C, "root after the odd single");
        assertEq(tree.size(), 18, "eighteen places taken");
    }

    /// How the leaves were grouped is not part of the answer. This needs no
    /// fixture at all: it is two trees disagreeing or not.
    function test_how_the_leaves_were_batched_does_not_change_the_root() public {
        _insert(1, 18);

        CompositionTree other = new CompositionTree(IPoseidon2(hasher), registrar);
        for (uint256 i = 1; i <= 18; i++) {
            uint256[] memory one = new uint256[](1);
            one[0] = i;
            vm.prank(registrar);
            other.insertBatch(one);
        }

        assertEq(
            other.currentRoot(),
            tree.currentRoot(),
            "eighteen at once and eighteen one at a time are the same tree"
        );
        assertEq(tree.currentRoot(), ROOT_AFTER_C, "and both agree with circomlibjs");
    }

    // ─────────────────────────────────────────────────────────────
    // WHAT THE ARCHIVE CARRIES
    // ─────────────────────────────────────────────────────────────

    /// Rebuild the root the way a third party would: from the leaves alone,
    /// hashing every level, knowing nothing of how this contract inserts.
    /// Deliberately the naive walk and not the contract's own method — a
    /// rebuild that copied the contract's algorithm would agree with a wrong
    /// algorithm just as happily.
    function _rootFromLeaves(uint256[] memory leaves) internal view returns (uint256) {
        require(leaves.length > 0, "no leaves");

        uint256 levels = tree.LEVELS();
        uint256[] memory zeros = new uint256[](levels + 1);
        for (uint256 i = 1; i <= levels; i++) {
            zeros[i] = IPoseidon2(hasher).poseidon([zeros[i - 1], zeros[i - 1]]);
        }

        uint256[] memory level = leaves;
        for (uint256 d = 0; d < levels; d++) {
            uint256 n = (level.length + 1) / 2;
            uint256[] memory next = new uint256[](n);
            for (uint256 i = 0; i < n; i++) {
                uint256 l = level[2 * i];
                uint256 r = (2 * i + 1 < level.length) ? level[2 * i + 1] : zeros[d];
                next[i] = IPoseidon2(hasher).poseidon([l, r]);
            }
            level = next;
        }
        return level[0];
    }

    /// THE WHOLE CLAIM OF THE ARCHIVE, IN ONE RUN. A reader who holds the
    /// event log and nothing else — no archive node, no calldata, no view
    /// call — reads the batches out of it, rebuilds the tree from them, and
    /// arrives at the root the tree now holds. Before the leaves were in the
    /// log, that reader could see that a root had moved and could not see
    /// what moved it.
    function test_the_log_carries_the_batch_and_a_reader_rebuilds_the_root() public {
        vm.recordLogs();

        _insert(1, 10);
        _insert(11, 17);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 wanted = keccak256(
            "LeavesInserted(uint256,uint256,uint256,uint256[])"
        );

        uint256[] memory seen = new uint256[](17);
        uint256 k;
        uint256 lastRoot;
        uint256 batches;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] != wanted) continue;
            batches++;

            (
                uint256 count,
                uint256 first_index,
                uint256 new_root,
                uint256[] memory leaves
            ) = abi.decode(logs[i].data, (uint256, uint256, uint256, uint256[]));

            assertEq(count, leaves.length, "the count describes the batch beside it");
            assertEq(first_index, k, "and the batch begins where the last one ended");

            for (uint256 j = 0; j < leaves.length; j++) {
                seen[k] = leaves[j];
                k++;
            }
            lastRoot = new_root;
        }

        assertEq(batches, 2, "both batches were announced");
        assertEq(k, 17, "and seventeen leaves in all");
        for (uint256 i = 0; i < 17; i++) {
            assertEq(seen[i], i + 1, "in the order they went in");
        }

        assertEq(lastRoot, tree.currentRoot(), "the log's last root is the tree's root");
        assertEq(
            _rootFromLeaves(seen),
            lastRoot,
            "and a reader rebuilding from the log alone arrives at it"
        );
        assertEq(lastRoot, ROOT_AFTER_B, "which is also what circomlibjs says");
    }

    // ─────────────────────────────────────────────────────────────
    // LEAVING
    // ─────────────────────────────────────────────────────────────

    /// Exit zeroes the leaf in place and the root moves to what a third party
    /// recomputes from the same leaves with that one zeroed. The place is not
    /// reused: size does not fall.
    function test_removing_a_leaf_zeroes_it_and_moves_the_root() public {
        _insert(1, 18);
        assertEq(tree.currentRoot(), ROOT_AFTER_C, "the tree before the removal");

        vm.prank(registrar);
        tree.removeLeaf(3, 4, _pathForIndex3());

        assertEq(tree.currentRoot(), ROOT_AFTER_REMOVAL, "root after the removal");
        assertEq(tree.size(), 18, "the place is spent, not freed");
    }

    /// A removal must leave a tree that still grows correctly, which is the
    /// same frontier question once more and the reason removeLeaf refreshes it.
    function test_the_tree_still_grows_correctly_after_a_removal() public {
        _insert(1, 18);
        vm.prank(registrar);
        tree.removeLeaf(3, 4, _pathForIndex3());
        uint256 afterRemoval = tree.currentRoot();

        _insert(19, 21);

        CompositionTree other = new CompositionTree(IPoseidon2(hasher), registrar);
        vm.prank(registrar);
        other.insertBatch(_range(1, 18));
        vm.prank(registrar);
        other.removeLeaf(3, 4, _pathForIndex3());
        vm.prank(registrar);
        other.insertBatch(_range(19, 21));

        assertTrue(tree.currentRoot() != afterRemoval, "the root moved on");
        assertEq(
            tree.currentRoot(),
            other.currentRoot(),
            "and two trees that saw the same history agree"
        );
    }

    /// A path that does not lead to the root standing now is refused, which is
    /// what keeps a removal from being a way to set the root to anything.
    function test_a_removal_with_a_wrong_path_is_refused() public {
        _insert(1, 18);
        uint256[20] memory bad = _pathForIndex3();
        bad[0] = 999;

        vm.prank(registrar);
        vm.expectRevert(CompositionTree.PathDoesNotMatchRoot.selector);
        tree.removeLeaf(3, 4, bad);
    }

    function test_a_place_never_written_cannot_be_removed() public {
        _insert(1, 10);

        vm.prank(registrar);
        vm.expectRevert(abi.encodeWithSelector(CompositionTree.IndexNotWritten.selector, uint256(50)));
        tree.removeLeaf(50, 1, _pathForIndex3());
    }

    // ─────────────────────────────────────────────────────────────
    // WHO MAY WRITE, AND WHAT IS REFUSED
    // ─────────────────────────────────────────────────────────────

    /// The promise the stand-in cannot carry: the real tree refuses a stranger.
    function test_only_the_registrar_may_insert() public {
        vm.prank(stranger);
        vm.expectRevert(CompositionTree.OnlyRegistrar.selector);
        tree.insertBatch(_range(1, 3));

        assertEq(tree.size(), 0, "and nothing went in");
        assertEq(tree.currentRoot(), EMPTY_ROOT, "the root did not move");
    }

    function test_only_the_registrar_may_remove() public {
        _insert(1, 18);

        vm.prank(stranger);
        vm.expectRevert(CompositionTree.OnlyRegistrar.selector);
        tree.removeLeaf(3, 4, _pathForIndex3());

        assertEq(tree.currentRoot(), ROOT_AFTER_C, "the root did not move");
    }

    function test_an_empty_batch_is_refused() public {
        uint256[] memory none = new uint256[](0);

        vm.prank(registrar);
        vm.expectRevert(CompositionTree.EmptyBatch.selector);
        tree.insertBatch(none);
    }

    /// A leaf at or above the SNARK field would be reduced by the hasher, so
    /// two different leaves could share a place. It is refused at the door.
    function test_a_leaf_outside_the_field_is_refused() public {
        uint256 field =
            21888242871839275222246405745257275088548364400416034343698204186575808495617;
        uint256[] memory bad = new uint256[](2);
        bad[0] = 1;
        bad[1] = field;

        vm.prank(registrar);
        vm.expectRevert(abi.encodeWithSelector(CompositionTree.LeafOutOfField.selector, field));
        tree.insertBatch(bad);

        assertEq(tree.size(), 0, "the whole batch was refused, not part of it");
    }

    // ─────────────────────────────────────────────────────────────
    // THE WIRE THE CORE CHECKS
    // ─────────────────────────────────────────────────────────────

    /// BeTrueCoreCore.setCompositionTree refuses a tree that does not name it
    /// as registrar, and this is the getter that answer comes from.
    function test_the_tree_names_its_registrar() public view {
        assertEq(tree.registrar(), registrar, "registrar");
    }

    function test_a_tree_wired_to_nothing_is_refused_at_deployment() public {
        vm.expectRevert(CompositionTree.ZeroAddress.selector);
        new CompositionTree(IPoseidon2(address(0)), registrar);

        vm.expectRevert(CompositionTree.ZeroAddress.selector);
        new CompositionTree(IPoseidon2(hasher), address(0));
    }

    // ─────────────────────────────────────────────────────────────
    // PROMISES THIS SUITE DOES NOT COVER
    // ─────────────────────────────────────────────────────────────
    //
    //  - That the leaves are the commitments people registered. Not this
    //    contract's business: it takes what the registrar hands it. The core
    //    is what draws them from its own queue, and that is asserted in
    //    test/Assertions.t.sol.
    //  - That a removal was the person's own choice. Nothing on chain can
    //    tell a departure from an eviction by the registrar; the exit is a
    //    client obligation and is named as an organisational guarantee
    //    wherever it is claimed.
    //  - That two leaves of one person in two communities cannot be linked.
    //    That rests on the tag, which is computed off chain and is not in
    //    this contract at all.
}
