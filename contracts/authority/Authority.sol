// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./EntryPointAuth.sol";
import "./OwnerAuth.sol";
import "../interfaces/IExecutionManager.sol";
import "../interfaces/IModuleManager.sol";
import "../libraries/Errors.sol";
import "./ModuleAuth.sol";

abstract contract Authority is EntryPointAuth, OwnerAuth, ModuleAuth {
    modifier onlySelfOrModule() {
        if (msg.sender != address(this) && !_isAuthorizedModule()) {
            revert Errors.CALLER_MUST_BE_SELF_OR_MODULE();
        }
        _;
    }
}
