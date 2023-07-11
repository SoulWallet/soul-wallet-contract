pragma solidity ^0.8.17;

import "../IKnownStateRootWithHistory.sol";
import "./IL1Block.sol";
import "../BlockVerifier.sol";

contract OpKnownStateRootWithHistory is IKnownStateRootWithHistory {
    uint256 public constant ROOT_HISTORY_SIZE = 30;
    uint256 public currentRootIndex = 0;
    // https://community.optimism.io/docs/developers/build/differences/#accessing-l1-information
    IL1Block public immutable L1_BLOCK;

    mapping(uint256 => BlockInfo) public stateRoots;
    mapping(uint256 => bytes32) public blockHashs;

    event L1BLockSyncd(uint256 indexed blockNumber, bytes32 blockHash);

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

    function insertNewStateRoot(uint256 _blockNumber, bytes memory _blockInfo) external {
        bytes32 _blockHash = blockHashs[_blockNumber];
        require(_blockHash != bytes32(0), "blockhash not set");
        (bytes32 stateRoot, uint256 blockTimestamp, uint256 blockNumber) =
            BlockVerifier.extractStateRootAndTimestamp(_blockInfo, _blockHash);
        require(!isKnownStateRoot(stateRoot), "duplicate state root");

        uint256 newRootIndex = (currentRootIndex + 1) % ROOT_HISTORY_SIZE;
        currentRootIndex = newRootIndex;

        stateRoots[newRootIndex].blockHash = _blockHash;
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

    function setBlockHash() external {
        bytes32 l1BlockHash = L1_BLOCK.hash();
        uint256 l1BlockNumber = L1_BLOCK.number();
        require(l1BlockNumber != 0, "l1 block number is 0");
        require(l1BlockHash != bytes32(0), "l1 block hash is 0");
        require(blockHashs[l1BlockNumber] == bytes32(0), "l1 blockhash already set");
        blockHashs[l1BlockNumber] = l1BlockHash;
        emit L1BLockSyncd(l1BlockNumber, l1BlockHash);
    }
}
