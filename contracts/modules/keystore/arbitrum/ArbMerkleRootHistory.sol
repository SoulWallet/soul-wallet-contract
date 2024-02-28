// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "../base/MerkleRootHistoryBase.sol";
import "@arbitrum/nitro-contracts/src/libraries/AddressAliasHelper.sol";

/**
 * @title ArbMerkleRootHistory
 * @dev Stores the history of L1 key store Merkle roots on Arbitrum. Used by KeyStoreMerkleProof for validation of Merkle roots.
 * Inherits from MerkleRootHistoryBase, with an override of isValidL1Sender to ensure only messages from the ArbKeyStoreCrossChainMerkleRootManager can update the merkel root
 */
contract ArbMerkleRootHistory is MerkleRootHistoryBase {
    constructor(address _l1Target, address _owner) MerkleRootHistoryBase(_l1Target, _owner) {}

    function isValidL1Sender() internal view override returns (bool) {
        return msg.sender == AddressAliasHelper.applyL1ToL2Alias(l1Target);
    }
}
