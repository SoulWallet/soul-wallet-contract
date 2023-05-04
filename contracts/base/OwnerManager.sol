// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../libraries/AccountStorage.sol";
import "./ModuleManager.sol";

abstract contract OwnerManager is ModuleManager {
    function _addOwner(address _add) external {
        requireFromAuthorizedModule(this._addOwner.selector);
        (_add);
    }

    function _removeOwner(address _delete) external {
        requireFromAuthorizedModule(this._addOwner.selector);
        (_delete);
    }

    function _resetOwner(
        address[] calldata _add,
        address[] calldata _delete
    ) external {
        requireFromAuthorizedModule(this._addOwner.selector);
        (_add, _delete);
    }

    function isOwner(address addr) public view returns (bool) {
        return false;
    }

    function owners() public view returns (address[] memory) {
        address[] memory allOwners;
        return allOwners;
    }
}
