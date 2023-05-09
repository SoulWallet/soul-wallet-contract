// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../libraries/AccountStorage.sol";
import "../authority/Authority.sol";
import "../interfaces/IOwnerManager.sol";
import "../libraries/AccountStorage.sol";
import "../libraries/AddressLinkedList.sol";

abstract contract OwnerManager is IOwnerManager, Authority {
    using AddressLinkedList for mapping(address => address);

    function ownerMapping()
        private
        view
        returns (mapping(address => address) storage owners)
    {
        owners = AccountStorage.layout().owners;
    }

    function _isOwner(address addr) internal view override returns (bool) {
        return ownerMapping().isExist(addr);
    }

    function isOwner(address addr) external view override returns (bool) {
        return _isOwner(addr);
    }

    function clearOwner() private {
        ownerMapping().clear();
        emit OwnerCleared();
    }

    function resetOwner(address newOwner) public override onlyEntryPointOrSelf {
        clearOwner();
        addOwner(newOwner);
    }

    function addOwner(address owner) public override onlyEntryPointOrSelf {
        ownerMapping().add(owner);
        emit OwnerAdded(owner);
    }

    function removeOwner(address owner) public override onlyEntryPointOrSelf {
        ownerMapping().remove(owner);
        emit OwnerRemoved(owner);
    }

    function replaceOwner(
        address oldOwner,
        address newOwner
    ) public override onlyEntryPointOrSelf {
        ownerMapping().replace(oldOwner, newOwner);
        emit OwnerRemoved(oldOwner);
        emit OwnerAdded(newOwner);
    }

    function listOwner(
        address from,
        uint256 limit
    ) external view override returns (address[] memory owners) {
        owners = ownerMapping().list(from, limit);
    }
}
