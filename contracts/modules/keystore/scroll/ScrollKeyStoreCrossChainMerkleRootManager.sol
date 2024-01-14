// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import {IKeyStoreMerkleProof} from "../../../keystore/L1/base/BaseMerkleTree.sol";
import {MerkleRootHistoryBase} from "../base/MerkleRootHistoryBase.sol";
import "./IL1ScrollMessenger.sol";

contract ScrollKeyStoreCrossChainMerkleRootManager is Ownable {
    address public l2Target;
    address public l1KeyStore;
    IL1ScrollMessenger public immutable l1ScrollMessenger;

    event KeyStoreMerkleRootSyncedToScroll(uint256 ticketId, bytes32 merkleRoot);
    // https://docs.scroll.io/en/developers/scroll-contracts/

    constructor(address _l2Target, address _l1KeyStore, address _l1ScrollMessenger, address _owner) Ownable(_owner) {
        l2Target = _l2Target;
        l1KeyStore = _l1KeyStore;
        l1ScrollMessenger = IL1ScrollMessenger(_l1ScrollMessenger);
    }

    function updateL2Target(address _l2Target) public onlyOwner {
        l2Target = _l2Target;
    }

    function syncKeyStoreMerkleRootToScroll() public payable {
        bytes32 merkleRoot = IKeyStoreMerkleProof(l1KeyStore).getMerkleRoot();
        bytes memory data = abi.encodeCall(MerkleRootHistoryBase.setMerkleRoot, (merkleRoot));
        l1ScrollMessenger.sendMessage{value: msg.value}(l2Target, 0, data, 400000, msg.sender);
        emit KeyStoreMerkleRootSyncedToScroll(block.number, merkleRoot);
    }
}
