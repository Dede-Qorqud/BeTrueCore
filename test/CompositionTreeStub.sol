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
contract CompositionTreeStub {

    /// @notice The address the core must see named as registrar, or refuse the wire
    address public immutable registrar;

    /// @notice The value currentRoot() returns. Not a Merkle root of anything.
    uint256 public root;

    constructor(address _registrar, uint256 _root) {
        registrar = _registrar;
        root      = _root;
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
