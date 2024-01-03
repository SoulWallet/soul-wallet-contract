// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "../base/MerkleRootHistoryBase.sol";
import "@arbitrum/nitro-contracts/src/libraries/AddressAliasHelper.sol";

contract ArbMerkleRootHistory is MerkleRootHistoryBase {
    constructor(address _l1Target, address _owner) MerkleRootHistoryBase(_l1Target, _owner) {}

    function isValidL1Sender() internal view override returns (bool) {
        return msg.sender == AddressAliasHelper.applyL1ToL2Alias(l1Target);
    }
}
