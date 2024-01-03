// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import {IKeyStoreMerkleProof} from "../../../keystore/L1/base/BaseMerkleTree.sol";
import "../interfaces/ICrossDomainMessenger.sol";
import {MerkleRootHistoryBase} from "../base/MerkleRootHistoryBase.sol";

contract OpKeyStoreCrossChainMerkleRootManager is Ownable {
    address public l2Target;
    address public l1KeyStore;
    ICrossDomainMessenger public immutable l1CrossDomainMessenger;

    event KeyStoreMerkleRootSyncedToOp(uint256 ticketId, bytes32 merkleRoot);

    // https://community.optimism.io/docs/useful-tools/networks/#op-goerli

    constructor(address _l2Target, address _l1KeyStore, address _l1CrossDomainMessenger, address _owner)
        Ownable(_owner)
    {
        l2Target = _l2Target;
        l1KeyStore = _l1KeyStore;
        l1CrossDomainMessenger = ICrossDomainMessenger(_l1CrossDomainMessenger);
    }

    function updateL2Target(address _l2Target) public onlyOwner {
        l2Target = _l2Target;
    }

    function syncKeyStoreMerkleRootToOp() public {
        bytes32 merkleRoot = IKeyStoreMerkleProof(l1KeyStore).getMerkleRoot();
        bytes memory data = abi.encodeCall(MerkleRootHistoryBase.setMerkleRoot, (merkleRoot));
        ICrossDomainMessenger(l1CrossDomainMessenger).sendMessage(l2Target, data, 200000);
        emit KeyStoreMerkleRootSyncedToOp(block.number, merkleRoot);
    }
}
