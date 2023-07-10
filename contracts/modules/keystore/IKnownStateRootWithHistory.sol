// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

struct BlockInfo {
    bytes32 storageRootHash;
    bytes32 blockHash;
    uint256 blockNumber;
    uint256 blockTimestamp;
}

interface IKnownStateRootWithHistory {
    function isKnownStateRoot(bytes32 _stateRoot) external returns (bool);
    function stateRootInfo(bytes32 _stateRoot) external view returns (bool result, BlockInfo memory info);
}
