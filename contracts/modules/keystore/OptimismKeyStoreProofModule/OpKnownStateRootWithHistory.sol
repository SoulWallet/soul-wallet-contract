pragma solidity ^0.8.17;

import "../IKnownStateRootWithHistory.sol";
import "./IL1Block.sol";
import "../BlockVerifier.sol";

contract OpKnownStateRootWithHistory is IKnownStateRootWithHistory {
    mapping(uint256 => BlockInfo) public stateRoots;
    uint256 public constant ROOT_HISTORY_SIZE = 30;
    uint256 public currentRootIndex = 0;
    // https://community.optimism.io/docs/developers/build/differences/#accessing-l1-information
    IL1Block public immutable L1_BLOCK;

    constructor(address _l1block) {
        L1_BLOCK = IL1Block(_l1block);
    }

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

    function insertNewStateRoot(bytes memory blockInfo) external {
        bytes32 blockHash = L1_BLOCK.hash();
        (bytes32 stateRoot, uint256 blockTimestamp, uint256 blockNumber) =
            BlockVerifier.extractStateRootAndTimestamp(blockInfo, blockHash);
        require(!isKnownStateRoot(stateRoot), "duplicate state root");

        uint256 newRootIndex = (currentRootIndex + 1) % ROOT_HISTORY_SIZE;
        currentRootIndex = newRootIndex;

        stateRoots[newRootIndex].blockHash = blockHash;
        stateRoots[newRootIndex].storageRootHash = stateRoot;
        stateRoots[newRootIndex].blockNumber = blockNumber;
        stateRoots[newRootIndex].blockTimestamp = blockTimestamp;
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
