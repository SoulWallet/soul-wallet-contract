pragma solidity ^0.8.17;

import {IInbox} from "@arbitrum/nitro-contracts/src/bridge/IInbox.sol";
import {MerkleRootHistoryBase} from "../base/MerkleRootHistoryBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {IKeyStoreMerkleProof} from "../../../keystore/L1/base/BaseMerkleTree.sol";

contract ArbKeyStoreCrossChainMerkleRootManager is Ownable {
    address public l2Target;
    address public l1KeyStore;
    IInbox public immutable inbox;

    event KeyStoreMerkleRootSyncedToArb(uint256 ticketId, bytes32 merkleRoot);

    constructor(address _l2Target, address _l1KeyStore, address _inbox, address _owner) Ownable(_owner) {
        l2Target = _l2Target;
        l1KeyStore = _l1KeyStore;
        inbox = IInbox(_inbox);
    }

    function updateL2Target(address _l2Target) public onlyOwner {
        l2Target = _l2Target;
    }

    function syncKeyStoreMerkleRootToArb(uint256 _maxSubmissionCost, uint256 _maxGas, uint256 _gasPriceBid)
        public
        payable
        returns (uint256)
    {
        bytes32 merkleRoot = IKeyStoreMerkleProof(l1KeyStore).getMerkleRoot();
        bytes memory data = abi.encodeCall(MerkleRootHistoryBase.setMerkleRoot, (merkleRoot));
        uint256 ticketID = inbox.createRetryableTicket{value: msg.value}(
            l2Target, 0, _maxSubmissionCost, msg.sender, msg.sender, _maxGas, _gasPriceBid, data
        );

        emit KeyStoreMerkleRootSyncedToArb(ticketID, merkleRoot);
        return ticketID;
    }
}
