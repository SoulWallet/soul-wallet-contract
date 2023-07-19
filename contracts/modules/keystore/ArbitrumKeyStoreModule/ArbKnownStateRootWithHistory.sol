pragma solidity ^0.8.17;

import "../KnownStateRootWithHistoryBase.sol";
import "@arbitrum/nitro-contracts/src/precompiles/ArbSys.sol";
import "@arbitrum/nitro-contracts/src/libraries/AddressAliasHelper.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ArbKnownStateRootWithHistory is KnownStateRootWithHistoryBase, Ownable {
    address public l1Target;

    constructor(address _l1Target) {
        l1Target = _l1Target;
    }

    function updateL1Target(address _l1Target) public onlyOwner {
        l1Target = _l1Target;
    }

    function setBlockHash(uint256 l1BlockNumber, bytes32 l1BlockHash) external {
        // To check that message came from L1, we check that the sender is the L1 contract's L2 alias.
        require(msg.sender == AddressAliasHelper.applyL1ToL2Alias(l1Target), "blockhash only updateable by L1Target");
        require(l1BlockNumber != 0, "l1 block number is 0");
        require(l1BlockHash != bytes32(0), "l1 block hash is 0");
        blockHashs[l1BlockNumber] = l1BlockHash;
        emit L1BlockSyncd(l1BlockNumber, l1BlockHash);
    }
}
