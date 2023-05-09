// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../libraries/AccountStorage.sol";
import "../authority/Authority.sol";
import "../interfaces/IOwnerManager.sol";

abstract contract OwnerManager is IOwnerManager, Authority {
    function _isOwner(address addr) internal view override returns (bool) {
        (addr);
        revert("not implemented");
    }

    function isOwner(address addr) external view returns (bool) {
        return _isOwner(addr);
    }

    function resetOwner(address newOwner) public onlyEntryPointOrSelf {
        (newOwner);
        emit OwnerCleared();
        emit OwnerAdded(newOwner);
    }

    function addOwner(address owner) public onlyEntryPointOrSelf {
        (owner);
        emit OwnerAdded(owner);
    }

    function removeOwner(address owner) public onlyEntryPointOrSelf {
        (owner);
        emit OwnerRemoved(owner);
    }

    function listOwner() external view returns (address[] memory owners) {
        revert("not implemented");
    }
}
