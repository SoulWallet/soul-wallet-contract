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

    function passBlockHashInL2(uint256 _blockNumber, uint256 _maxSubmissionCost, uint256 _maxGas, uint256 _gasPriceBid)
        public
        payable
        returns (uint256)
    {
        // does it need check blockNumber not to new, to prevent blockhash reorg?
        bytes32 _blockhash = blockhash(_blockNumber);

        bytes memory data = abi.encodeCall(ArbKnownStateRootWithHistory.setBlockHash, (_blockNumber, _blockhash));
        uint256 ticketID = inbox.createRetryableTicket{value: msg.value}(
            l2Target, 0, _maxSubmissionCost, msg.sender, msg.sender, _maxGas, _gasPriceBid, data
        );

        emit BlockHashPassingTickedCreated(ticketID, _blockNumber, _blockhash);
        return ticketID;
    }
}
