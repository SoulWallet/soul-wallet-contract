// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IOwnerManager} from "../interface/IOwnerManager.sol";
import {AuthoritySnippet} from "../../../contracts/snippets/Authority.sol";
import {OwnerManagerSnippet} from "../../../contracts/snippets/OwnerManager.sol";

abstract contract OwnerManager is IOwnerManager, AuthoritySnippet, OwnerManagerSnippet {
    function addOwners(bytes32[] calldata owner) external override {
        ownerManagementAccess();

        for (uint256 i = 0; i < owner.length; i++) {
            _addOwner(owner[i]);
        }
    }

    function removeOwners(bytes32[] calldata owner) external override {
        ownerManagementAccess();

        for (uint256 i = 0; i < owner.length; i++) {
            _removeOwner(owner[i]);
        }
    }
}
