// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "../libraries/AccountStorage.sol";
import "../authority/Authority.sol";
import "../interfaces/IOwnerManager.sol";
import "../libraries/Bytes32LinkedList.sol";
import "../libraries/Errors.sol";

/**
 * @title OwnerManager
 * @notice Manages the owners of the wallet, allowing for addition, removal, and listing of owners
 * The owner should be of bytes32 type. Currently, an owner is an eoa key or the public key of the passkey
 * @dev Inherits functionalities from IOwnerManager and Authority
 */
abstract contract OwnerManager is IOwnerManager, Authority {
    using Bytes32LinkedList for mapping(bytes32 => bytes32);

    /**
     * @notice Helper function to get the owner mapping from account storage
     * @return owners Mapping of current owners
     */
    function _ownerMapping() private view returns (mapping(bytes32 => bytes32) storage owners) {
        owners = AccountStorage.layout().owners;
    }
    /**
     * @notice Checks if the provided owner is a current owner
     * @param owner Address in bytes32 format to check
     * @return true if provided owner is a current owner, false otherwise
     */

    function _isOwner(bytes32 owner) internal view override returns (bool) {
        return _ownerMapping().isExist(owner);
    }
    /**
     * @notice External function to check if the provided owner is a current owner
     * @param owner Address in bytes32 format to check
     * @return true if provided owner is a current owner, false otherwise
     */

    function isOwner(bytes32 owner) external view override returns (bool) {
        return _isOwner(owner);
    }
    /**
     * @notice Clears all owners
     */

    function _clearOwner() private {
        _ownerMapping().clear();
        emit OwnerCleared();
    }
    /**
     * @notice Resets the owner to a new owner
     * @param newOwner The new owner address in bytes32 format
     */

    function resetOwner(bytes32 newOwner) external override onlySelfOrModule {
        _clearOwner();
        _addOwner(newOwner);
    }
    /**
     * @notice Resets the owners to a new set of owners
     * @param newOwners An array of new owner addresses in bytes32 format
     */

    function resetOwners(bytes32[] calldata newOwners) external override onlySelfOrModule {
        _clearOwner();
        _addOwners(newOwners);
    }
    /**
     * @notice Adds multiple owners
     * @param owners An array of owner addresses in bytes32 format to add
     */

    function _addOwners(bytes32[] calldata owners) internal {
        for (uint256 i = 0; i < owners.length;) {
            _addOwner(owners[i]);
            unchecked {
                i++;
            }
        }
    }
    /**
     * @notice Adds a single owner
     * @param owner The owner address in bytes32 format to add
     */

    function addOwner(bytes32 owner) external override onlySelfOrModule {
        _addOwner(owner);
    }
    /**
     * @notice Adds multiple owners
     * @param owners An array of owner addresses in bytes32 format to add
     */

    function addOwners(bytes32[] calldata owners) external override onlySelfOrModule {
        _addOwners(owners);
    }
    /**
     * @notice Adds a single owner
     * @param owner The owner address in bytes32 format to add
     */

    function _addOwner(bytes32 owner) internal {
        _ownerMapping().add(owner);
        emit OwnerAdded(owner);
    }
    /**
     * @notice Removes a single owner
     * @param owner The owner address in bytes32 format to remove
     */

    function removeOwner(bytes32 owner) external override onlySelfOrModule {
        _ownerMapping().remove(owner);
        if (_ownerMapping().isEmpty()) {
            revert Errors.NO_OWNER();
        }
        emit OwnerRemoved(owner);
    }
    /**
     * @notice Lists all current owners
     * @return owners An array of current owner addresses in bytes32 format
     */

    function listOwner() external view override returns (bytes32[] memory owners) {
        uint256 size = _ownerMapping().size();
        owners = _ownerMapping().list(Bytes32LinkedList.SENTINEL_BYTES32, size);
    }
}
