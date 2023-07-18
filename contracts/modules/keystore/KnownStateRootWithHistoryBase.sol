// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./IKnownStateRootWithHistory.sol";
import "./BlockVerifier.sol";

abstract contract KnownStateRootWithHistoryBase is IKnownStateRootWithHistory {
    uint256 public constant ROOT_HISTORY_SIZE = 100;
    uint256 public currentRootIndex = 0;

    mapping(uint256 => BlockInfo) public stateRoots;
    mapping(uint256 => bytes32) public blockHashs;

    event L1BlockSyncd(uint256 indexed blockNumber, bytes32 blockHash);
    event NewStateRoot(bytes32 indexed stateRoot, uint256 indexed blockNumber, address user);

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
}
