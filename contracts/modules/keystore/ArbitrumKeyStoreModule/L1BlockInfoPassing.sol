pragma solidity ^0.8.17;

import "@arbitrum/nitro-contracts/src/bridge/Inbox.sol";
import "@arbitrum/nitro-contracts/src/bridge/Outbox.sol";
import {ArbKnownStateRootWithHistory} from "./ArbKnownStateRootWithHistory.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract L1BlockInfoPassing is Ownable {
    address public l2Target;
    IInbox public immutable inbox;

    event BlockHashPassingTickedCreated(uint256 ticketId, uint256 blockNumber, bytes32 blockHash);

    constructor(address _l2Target, address _inbox) {
        l2Target = _l2Target;
        inbox = IInbox(_inbox);
    }

    function updateL2Target(address _l2Target) public onlyOwner {
        l2Target = _l2Target;
    }

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
