// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "./IKnownStateRootWithHistory.sol";
import "./BlockVerifier.sol";

/**
 * @title KnownStateRootWithHistoryBase
 * @notice Abstract contract for maintaining a history of known state roots and associated block info
 */
abstract contract KnownStateRootWithHistoryBase is IKnownStateRootWithHistory {
    /* Size of the state root history */
    uint256 public constant ROOT_HISTORY_SIZE = 100;
    /* Current index in the circular buffer of state roots */
    uint256 public currentRootIndex = 0;
    /* Mapping of block numbers to associated block information */
    mapping(uint256 => BlockInfo) public stateRoots;
    /* Mapping of block numbers to block hashes */
    mapping(uint256 => bytes32) public blockHashs;

    event L1BlockSyncd(uint256 indexed blockNumber, bytes32 blockHash);
    event NewStateRoot(bytes32 indexed stateRoot, uint256 indexed blockNumber, address user);
    /**
     * @notice Checks if a given state root is known
     * @param _stateRoot The state root to check
     * @return True if the state root is known, false otherwise
     */

    function isKnownStateRoot(bytes32 _stateRoot) public view override returns (bool) {
        if (_stateRoot == 0) {
            return false;
        }
        uint256 _currentRootIndex = currentRootIndex;
        uint256 i = _currentRootIndex;

        do {
            BlockInfo memory blockinfo = stateRoots[i];
            if (_stateRoot == blockinfo.storageRootHash) {
                return true;
            }
            if (i == 0) {
                i = ROOT_HISTORY_SIZE;
            }
            i--;
        } while (i != _currentRootIndex);
        return false;
    }
    /**
     * @notice Inserts a new state root and associated block info
     * @param _blockNumber The number of the block
     * @param _blockInfo Serialized block info data
     */

    function insertNewStateRoot(uint256 _blockNumber, bytes memory _blockInfo) external {
        bytes32 _blockHash = blockHashs[_blockNumber];
        require(_blockHash != bytes32(0), "blockhash not set");
        (bytes32 stateRoot, uint256 blockTimestamp, uint256 blockNumber) =
            BlockVerifier.extractStateRootAndTimestamp(_blockInfo, _blockHash);

        require(!isKnownStateRoot(stateRoot), "duplicate state root");

        BlockInfo memory currentBlockInfo = stateRoots[currentRootIndex];
        require(blockNumber > currentBlockInfo.blockNumber, "blockNumber too old");

        uint256 newRootIndex = (currentRootIndex + 1) % ROOT_HISTORY_SIZE;
        currentRootIndex = newRootIndex;

        stateRoots[newRootIndex].blockHash = _blockHash;
        stateRoots[newRootIndex].storageRootHash = stateRoot;
        stateRoots[newRootIndex].blockNumber = blockNumber;
        stateRoots[newRootIndex].blockTimestamp = blockTimestamp;
        emit NewStateRoot(stateRoot, blockNumber, msg.sender);
    }
    /**
     * @notice Retrieves information about a given state root
     * @param _stateRoot The state root to query
     * @return result True if the state root is known, false otherwise
     * @return info BlockInfo structure associated with the given state root
     */

    function stateRootInfo(bytes32 _stateRoot) external view override returns (bool result, BlockInfo memory info) {
        if (_stateRoot == 0) {
            return (false, info);
        }
        uint256 _currentRootIndex = currentRootIndex;
        uint256 i = _currentRootIndex;

        do {
            BlockInfo memory blockinfo = stateRoots[i];
            if (_stateRoot == blockinfo.storageRootHash) {
                return (true, blockinfo);
            }
            if (i == 0) {
                i = ROOT_HISTORY_SIZE;
            }
            i--;
        } while (i != _currentRootIndex);
        return (false, info);
    }
    /**
     * @notice Retrieves information about the latest known state root
     * @return info BlockInfo structure associated with the latest state root
     */

    function lastestStateRootInfo() external view returns (BlockInfo memory info) {
        return stateRoots[currentRootIndex];
    }
}
