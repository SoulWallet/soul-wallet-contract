pragma solidity ^0.8.20;

import "../KnownStateRootWithHistoryBase.sol";
import "./IL1Block.sol";

/**
 * @title OpKnownStateRootWithHistory
 * @notice This contract is designed to work with the Optimism network to keep track of L1 block hashes in an L2 environment
 * The block hash information is retrieved from a contract deployed on L2 which provides L1 block attributes
 */
contract OpKnownStateRootWithHistory is KnownStateRootWithHistoryBase {
    /* https://community.optimism.io/docs/developers/build/differences/#accessing-l1-information
     Reference to the L1Block interface that will provide the L1 block information. */
    IL1Block public immutable L1_BLOCK;

    /**
     * @dev Constructor to set the L1Block precompiler contract address
     * @param _l1block Address of the L1Block contract
     */
    constructor(address _l1block) {
        L1_BLOCK = IL1Block(_l1block);
    }
    /**
     * @dev Fetches the L1 block hash and number from the L1Block contract, then stores it
     * Emits an event after successfully setting the block hash
     */

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
