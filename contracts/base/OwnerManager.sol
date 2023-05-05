// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../libraries/AccountStorage.sol";
import "../authority/OwnerAuth.sol";
import "../interfaces/IOwnerManager.sol";

abstract contract OwnerManager is IOwnerManager, OwnerAuth {
    function _isOwner(address addr) internal view override returns (bool) {
        (addr);
        revert("not implemented");
    }

    function isOwner(address addr) external view returns (bool) {
        return _isOwner(addr);
    }

    function resetOwner(address newOwner) external {
        (newOwner);
        emit OwnerCleared();
        emit OwnerAdded(newOwner);
    }

    function addOwner(address owner) public {
        (owner);
        emit OwnerAdded(owner);
    }

    function removeOwner(address owner) external {
        (owner);
        emit OwnerRemoved(owner);
    }

    function listOwner() external view returns (address[] memory owners) {
        revert("not implemented");
    }
}
