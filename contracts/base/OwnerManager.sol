// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../libraries/AccountStorage.sol";
import "../authority/Authority.sol";
import "../interfaces/IOwnerManager.sol";
import "../libraries/AddressLinkedList.sol";
import "../libraries/Errors.sol";

abstract contract OwnerManager is IOwnerManager, Authority {
    using AddressLinkedList for mapping(address => address);

    function _ownerMapping() private view returns (mapping(address => address) storage owners) {
        owners = AccountStorage.layout().owners;
    }

    function _isOwner(address addr) internal view override returns (bool) {
        return _ownerMapping().isExist(addr);
    }

    function isOwner(address addr) external view override returns (bool) {
        return _isOwner(addr);
    }

    function _clearOwner() private {
        _ownerMapping().clear();
        emit OwnerCleared();
    }

    function resetOwner(address newOwner) external override onlySelfOrModule {
        _clearOwner();
        _addOwner(newOwner);
    }

    function resetOwners(address[] calldata newOwners) external override onlySelfOrModule {
        _clearOwner();
        _addOwners(newOwners);
    }

    function _addOwners(address[] calldata owners) private {
        for (uint256 i = 0; i < owners.length;) {
            _addOwner(owners[i]);
            unchecked {
                i++;
            }
        }
    }

    function addOwner(address owner) external override onlySelfOrModule {
        _addOwner(owner);
    }

    function addOwners(address[] calldata owners) external override onlySelfOrModule {
        _addOwners(owners);
    }

    function _addOwner(address owner) internal {
        _ownerMapping().add(owner);
        emit OwnerAdded(owner);
    }

    function removeOwner(address owner) external override onlySelfOrModule {
        _ownerMapping().remove(owner);
        if (_ownerMapping().isEmpty()) {
            revert Errors.NO_OWNER();
        }
        emit OwnerRemoved(owner);
    }

    function listOwner() external view override returns (address[] memory owners) {
        uint256 size = _ownerMapping().size();
        owners = _ownerMapping().list(AddressLinkedList.SENTINEL_ADDRESS, size);
    }
}
