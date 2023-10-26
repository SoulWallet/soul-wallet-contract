// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@arbitrum/nitro-contracts/src/bridge/IInbox.sol";
import "@arbitrum/nitro-contracts/src/bridge/Outbox.sol";
import {ArbKnownStateRootWithHistory} from "./ArbKnownStateRootWithHistory.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
/**
 * @title L1BlockInfoPassing
 * @notice This contract facilitates the passing of block information from Layer 1 (L1) to Layer 2 (L2) on the Arbitrum network
 */

contract L1BlockInfoPassing is Ownable {
    address public l2Target;
    IInbox public immutable inbox;

    event BlockHashPassingTickedCreated(uint256 ticketId, uint256 blockNumber, bytes32 blockHash);
    /**
     * @dev Initializes the `l2Target` address, `inbox` address and the `owner` of the contract
     * @param _l2Target The address of the target contract on Layer 2 (L2)
     * @param _inbox The address of the inbox contract
     * @param _owner The owner's address
     */

    constructor(address _l2Target, address _inbox, address _owner) Ownable(_owner) {
        l2Target = _l2Target;
        inbox = IInbox(_inbox);
    }
    /**
     * @notice Updates the `l2Target` address
     * @param _l2Target New address of the target contract on L2
     */

    function updateL2Target(address _l2Target) public onlyOwner {
        l2Target = _l2Target;
    }
    /**
     * @notice Sends the block hash of the previous block to L2 using Arbitrum's retryable ticket mechanism
     * @param _maxSubmissionCost The maximum amount of Eth to be paid for the L2-side message execution
     * @param _maxGas The maximum amount of gas to be used on L2 for executing the L2-side message
     * @param _gasPriceBid The price (in wei) to be paid per unit of gas
     * @return ticketID The ID of the retryable ticket created by this function
     */

    function passBlockHashInL2(uint256 _maxSubmissionCost, uint256 _maxGas, uint256 _gasPriceBid)
        public
        payable
        returns (uint256)
    {
        // should not get the current blockhash,
        // block.blockhash(uint blockNumber) returns (bytes32): hash of the given block - only works for 256 most recent, excluding current, blocks
        // check https://github.com/foundry-rs/foundry/pull/1890
        uint256 _blockNumber = block.number - 1;
        bytes32 _blockhash = blockhash(_blockNumber);

        bytes memory data = abi.encodeCall(ArbKnownStateRootWithHistory.setBlockHash, (_blockNumber, _blockhash));
        uint256 ticketID = inbox.createRetryableTicket{value: msg.value}(
            l2Target, 0, _maxSubmissionCost, msg.sender, msg.sender, _maxGas, _gasPriceBid, data
        );

        emit BlockHashPassingTickedCreated(ticketID, _blockNumber, _blockhash);
        return ticketID;
    }
}
