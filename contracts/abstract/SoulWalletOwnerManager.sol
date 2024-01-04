// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OwnerManager} from "@soulwallet-core/contracts/base/OwnerManager.sol";
import {ISoulWalletOwnerManager} from "../interfaces/ISoulWalletOwnerManager.sol";

abstract contract SoulWalletOwnerManager is ISoulWalletOwnerManager, OwnerManager {
    function _addOwners(bytes32[] calldata owners) internal {
        for (uint256 i = 0; i < owners.length;) {
            _addOwner(owners[i]);
            unchecked {
                i++;
            }
        }
    }

    function addOwners(bytes32[] calldata owners) external override {
        ownerManagementAccess();
        _addOwners(owners);
    }

    function resetOwners(bytes32[] calldata newOwners) external override {
        ownerManagementAccess();
        _clearOwner();
        _addOwners(newOwners);
    }
}
