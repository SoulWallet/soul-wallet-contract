// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../libraries/AccountStorage.sol";
import "../authority/Authority.sol";
import "../interfaces/IOwnerManager.sol";
import "../libraries/Bytes32LinkedList.sol";
import "../libraries/Errors.sol";

abstract contract OwnerManager is IOwnerManager, Authority {
    using Bytes32LinkedList for mapping(bytes32 => bytes32);

    function _ownerMapping() private view returns (mapping(bytes32 => bytes32) storage owners) {
        owners = AccountStorage.layout().owners;
    }

    function _isOwner(bytes32 owner) internal view override returns (bool) {
        return _ownerMapping().isExist(owner);
    }

    function isOwner(bytes32 owner) external view override returns (bool) {
        return _isOwner(owner);
    }

    function _clearOwner() private {
        _ownerMapping().clear();
        emit OwnerCleared();
    }

    function resetOwner(bytes32 newOwner) external override onlySelfOrModule {
        _clearOwner();
        _addOwner(newOwner);
    }

    function resetOwners(bytes32[] calldata newOwners) external override onlySelfOrModule {
        _clearOwner();
        _addOwners(newOwners);
    }

    function _addOwners(bytes32[] calldata owners) internal {
        for (uint256 i = 0; i < owners.length;) {
            _addOwner(owners[i]);
            unchecked {
                i++;
            }
        }
    }

    function addOwner(bytes32 owner) external override onlySelfOrModule {
        _addOwner(owner);
    }

    function addOwners(bytes32[] calldata owners) external override onlySelfOrModule {
        _addOwners(owners);
    }

    function _addOwner(bytes32 owner) internal {
        _ownerMapping().add(owner);
        emit OwnerAdded(owner);
    }

    function removeOwner(bytes32 owner) external override onlySelfOrModule {
        _ownerMapping().remove(owner);
        if (_ownerMapping().isEmpty()) {
            revert Errors.NO_OWNER();
        }
        emit OwnerRemoved(owner);
    }

    function listOwner() external view override returns (bytes32[] memory owners) {
        uint256 size = _ownerMapping().size();
        owners = _ownerMapping().list(Bytes32LinkedList.SENTINEL_BYTES32, size);
    }
}
