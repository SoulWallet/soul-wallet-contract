// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title BlockInfo
 * @dev Struct containing information related to a particular block.
 */
struct BlockInfo {
    bytes32 storageRootHash; /* Storage root hash of the block */
    bytes32 blockHash; /* Hash of the block */
    uint256 blockNumber; /* Number of the block */
    uint256 blockTimestamp; /* Timestamp of the block */
}

/**
 * @title IKnownStateRootWithHistory
 * @notice Interface for checking and retrieving information about known state roots and associated block info
 */
interface IKnownStateRootWithHistory {
    /**
     * @notice Checks if a state root is known
     * @param _stateRoot The state root to check
     * @return bool indicating whether the state root is known
     */
    function isKnownStateRoot(bytes32 _stateRoot) external returns (bool);

    /**
     * @notice Retrieves information about a state root if it's known
     * @param _stateRoot The state root for which to retrieve information
     * @return result A bool indicating if the state root is known
     * @return info A BlockInfo struct containing associated block information
     */
    function stateRootInfo(bytes32 _stateRoot) external view returns (bool result, BlockInfo memory info);
}
