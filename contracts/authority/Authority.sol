// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "./EntryPointAuth.sol";
import "./OwnerAuth.sol";
import "../interfaces/IExecutionManager.sol";
import "../interfaces/IModuleManager.sol";
import "../libraries/Errors.sol";
import "./ModuleAuth.sol";

/**
 * @title Authority
 * @notice An abstract contract that provides authorization mechanisms
 * @dev Inherits various authorization patterns including EntryPoint, Owner, and Module-based authentication
 */
abstract contract Authority is EntryPointAuth, OwnerAuth, ModuleAuth {
    /**
     * @notice Ensures the calling contract is either the Authority contract itself or an authorized module
     * @dev Uses the inherited `_isAuthorizedModule()` from ModuleAuth for module-based authentication
     */
    modifier onlySelfOrModule() {
        if (msg.sender != address(this) && !_isAuthorizedModule()) {
            revert Errors.CALLER_MUST_BE_SELF_OR_MODULE();
        }
        _;
    }
}
