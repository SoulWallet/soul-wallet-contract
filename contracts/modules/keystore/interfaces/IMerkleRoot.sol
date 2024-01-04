// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

interface IMerkleRoot {
    function isKnownRoot(bytes32 _root) external view returns (bool);

    event L1MerkleRootSynced(bytes32 indexed _root, uint256 _blockNumber);
}
