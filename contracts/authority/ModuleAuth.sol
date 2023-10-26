// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "../libraries/Errors.sol";

/**
 * @title ModuleAuth
 * @notice Abstract contract to provide Module-based authentication
 * @dev Requires the inheriting contracts to implement the `_isAuthorizedModule` method
 */
abstract contract ModuleAuth {
    /**
     * @notice Expected to return whether the current context is authorized as a module
     * @dev Must be implemented by inheriting contracts
     * @return True if the context is an authorized module, otherwise false
     */
    function _isAuthorizedModule() internal view virtual returns (bool);

    /**
     * @notice Modifier to ensure the caller is an authorized module
     * @dev If not called from an authorized module, it will revert
     */
    modifier onlyModule() {
        if (!_isAuthorizedModule()) {
            revert Errors.CALLER_MUST_BE_MODULE();
        }
        _;
    }
}
