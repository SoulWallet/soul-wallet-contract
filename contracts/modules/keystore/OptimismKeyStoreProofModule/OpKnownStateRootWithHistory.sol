pragma solidity ^0.8.17;

import "../KnownStateRootWithHistoryBase.sol";
import "./IL1Block.sol";

contract OpKnownStateRootWithHistory is KnownStateRootWithHistoryBase {
    // https://community.optimism.io/docs/developers/build/differences/#accessing-l1-information
    IL1Block public immutable L1_BLOCK;

    constructor(address _l1block) {
        L1_BLOCK = IL1Block(_l1block);
    }

    function setBlockHash() external {
        bytes32 l1BlockHash = L1_BLOCK.hash();
        uint256 l1BlockNumber = L1_BLOCK.number();
        require(l1BlockNumber != 0, "l1 block number is 0");
        require(l1BlockHash != bytes32(0), "l1 block hash is 0");
        require(blockHashs[l1BlockNumber] == bytes32(0), "l1 blockhash already set");
        blockHashs[l1BlockNumber] = l1BlockHash;
        emit L1BlockSyncd(l1BlockNumber, l1BlockHash);
    }
}
