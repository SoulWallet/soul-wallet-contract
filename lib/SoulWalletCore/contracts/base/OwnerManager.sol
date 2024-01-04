// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Authority} from "./Authority.sol";
import {IOwnerManager} from "../interface/IOwnerManager.sol";
import {AccountStorage} from "../utils/AccountStorage.sol";
import {Bytes32LinkedList} from "../utils/Bytes32LinkedList.sol";
import {OwnerManagerSnippet} from "../snippets/OwnerManager.sol";

abstract contract OwnerManager is IOwnerManager, Authority, OwnerManagerSnippet {
    using Bytes32LinkedList for mapping(bytes32 => bytes32);

    /**
     * @notice Helper function to get the owner mapping from account storage
     * @return owners Mapping of current owners
     */
    function _ownerMapping() internal view override returns (mapping(bytes32 => bytes32) storage owners) {
        owners = AccountStorage.layout().owners;
    }

    /**
     * @notice Checks if the provided owner is a current owner
     * @param owner Address in bytes32 format to check
     * @return true if provided owner is a current owner, false otherwise
     */
    function _isOwner(bytes32 owner) internal view virtual override returns (bool) {
        return _ownerMapping().isExist(owner);
    }

    /**
     * @notice External function to check if the provided owner is a current owner
     * @param owner Address in bytes32 format to check
     * @return true if provided owner is a current owner, false otherwise
     */
    function isOwner(bytes32 owner) external view virtual override returns (bool) {
        return _isOwner(owner);
    }

    /**
     * @notice Internal function to add an owner
     * @param owner Address in bytes32 format to add
     */
    function _addOwner(bytes32 owner) internal virtual override {
        _ownerMapping().add(owner);
        emit OwnerAdded(owner);
    }

    /**
     * @notice add an owner
     * @param owner Address in bytes32 format to add
     */
    function addOwner(bytes32 owner) external virtual override {
        ownerManagementAccess();
        _addOwner(owner);
    }

    /**
     * @notice Internal function to remove an owner
     * @param owner Address in bytes32 format to remove
     */
    function _removeOwner(bytes32 owner) internal virtual override {
        _ownerMapping().remove(owner);
        emit OwnerRemoved(owner);
    }

    /**
     * @notice remove an owner
     * @param owner Address in bytes32 format to remove
     */
    function removeOwner(bytes32 owner) external virtual override {
        ownerManagementAccess();
        _removeOwner(owner);
    }

    function _resetOwner(bytes32 newOwner) internal virtual override {
        _clearOwner();
        _ownerMapping().add(newOwner);
    }

    function _clearOwner() internal virtual override {
        _ownerMapping().clear();
        emit OwnerCleared();
    }

    function resetOwner(bytes32 newOwner) external virtual override {
        ownerManagementAccess();
        _resetOwner(newOwner);
    }

    function listOwner() external view virtual override returns (bytes32[] memory owners) {
        mapping(bytes32 => bytes32) storage _owners = _ownerMapping();
        owners = _owners.list(Bytes32LinkedList.SENTINEL_BYTES32, _owners.size());
    }
}
