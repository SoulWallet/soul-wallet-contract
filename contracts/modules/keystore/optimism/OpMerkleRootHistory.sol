// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "../base/MerkleRootHistoryBase.sol";
import "../interfaces/ICrossDomainMessenger.sol";

/**
 * @title OpMerkleRootHistory
 * @dev Stores the history of L1 key store Merkle roots on optimism. Used by KeyStoreMerkleProof for validation of Merkle roots.
 * Inherits from MerkleRootHistoryBase, with an override of isValidL1Sender to ensure only messages from the OpKeyStoreCrossChainMerkleRootManager can update the merkel root
 */
contract OpMerkleRootHistory is MerkleRootHistoryBase {
    address public constant CROSS_DOMAIN_MESSENGER = 0x4200000000000000000000000000000000000007;

    constructor(address _l1Target, address _owner) MerkleRootHistoryBase(_l1Target, _owner) {}

    function isValidL1Sender() internal view override returns (bool) {
        return msg.sender == address(CROSS_DOMAIN_MESSENGER)
            && ICrossDomainMessenger(CROSS_DOMAIN_MESSENGER).xDomainMessageSender() == l1Target;
    }
}
