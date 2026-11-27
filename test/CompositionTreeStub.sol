// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title CompositionTreeStub
/// @notice A stand-in for the composition tree, for tests that are not about it
/// @dev What this is, said plainly so it is never mistaken for the tree. It
///      answers the only two calls BeTrueCoreCore makes on the tree —
///      registrar() and currentRoot() — and it hashes nothing, inserts
///      nothing and proves nothing. The real contract is
///      contracts/CompositionTree.sol and it is tested in
///      test/CompositionTree.t.sol against a real Poseidon.
///
///      Why a stand-in rather than the real tree. The real tree's constructor
///      calls the Poseidon contract twenty times to lay out the empty levels,
///      so a test that wants it has to deploy the circomlib bytecode first.
///      The two suites that use this file test promises about the roster, the
///      Panorama and the handover of roles — none of which turns on the value
///      of a hash. Carrying a hasher into them would make every one of their
///      failures ambiguous between the promise and the hashing.
///
///      setRoot exists so a test can move the root while a session is open,
///      which is how the promise that a session keeps its own snapshot is
///      checked. The real tree has no such function: its root moves only by
///      an insertion from the registrar.
///
///      insertBatch mirrors the real tree's signature and its three refusals —
///      a caller that is not the registrar, an empty batch, a leaf outside the
///      SNARK field — so that the core's side of the call is exercised exactly
///      as it will be in deployment. It records what it received instead of
///      hashing it, which is what lets a suite assert WHICH leaves reached the
///      tree and IN WHAT ORDER. That the real tree refuses a stranger, and that
///      its root is the Merkle root of what it received, are promises about the
///      tree and are asserted in test/CompositionTree.t.sol, not here. A promise
///      checked against a stand-in is checked against nothing.
contract CompositionTreeStub {

    /// @dev The field the real tree bounds its leaves by, repeated here so the
    ///      stand-in refuses what the real tree would refuse.
    uint256 internal constant SNARK_SCALAR_FIELD =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    /// @notice The address the core must see named as registrar, or refuse the wire
    address public immutable registrar;

    /// @notice The value currentRoot() returns. Not a Merkle root of anything.
    uint256 public root;

    /// @notice Every leaf received, in the order received
    /// @dev This is the record a suite reads to see what the core actually
    ///      handed over. The real tree keeps no such list: it keeps a root.
    uint256[] public received;

    error OnlyRegistrar();
    error EmptyBatch();
    error LeafOutOfField(uint256 leaf);

    constructor(address _registrar, uint256 _root) {
        registrar = _registrar;
        root      = _root;
    }

    /// @notice Take a batch the way the real tree takes one, and record it
    /// @dev The root moves by the size of the batch — a rule a test can
    ///      predict, and not a hash of anything. What is worth asserting here
    ///      is that the root moved at all and that `received` holds the right
    ///      leaves in the right order.
    function insertBatch(uint256[] calldata leaves) external {
        if (msg.sender != registrar) revert OnlyRegistrar();

        uint256 n = leaves.length;
        if (n == 0) revert EmptyBatch();

        for (uint256 i = 0; i < n; i++) {
            if (leaves[i] >= SNARK_SCALAR_FIELD) revert LeafOutOfField(leaves[i]);
            received.push(leaves[i]);
        }

        root = root + n;
    }

    /// @notice How many leaves this stand-in has received in all
    function receivedCount() external view returns (uint256) {
        return received.length;
    }

    /// @notice The call openSession makes when it takes a session's snapshot
    function currentRoot() external view returns (uint256) {
        return root;
    }

    /// @notice Move the root. Unguarded on purpose — this is a test double.
    function setRoot(uint256 _root) external {
        root = _root;
    }
}
