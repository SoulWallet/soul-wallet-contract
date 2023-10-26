// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title OwnerAuth
 * @notice Abstract contract to provide Owner-based authentication
 * @dev Requires the inheriting contracts to implement the `_isOwner` method
 */
abstract contract OwnerAuth {
    /**
     * @notice Expected to return whether the provided owner identifier matches the owner context
     * @dev Must be implemented by inheriting contracts
     * @param owner The owner identifier to be checked
     * @return True if the provided owner identifier matches the current owner context, otherwise false
     */
    function _isOwner(bytes32 owner) internal view virtual returns (bool);
}
