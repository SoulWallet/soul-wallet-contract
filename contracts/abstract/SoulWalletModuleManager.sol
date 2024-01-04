// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ModuleManager} from "@soulwallet-core/contracts/base/ModuleManager.sol";
import {ISoulWalletModuleManager} from "../interfaces/ISoulWalletModuleManager.sol";
import {ISoulWalletModule} from "../modules/interfaces/ISoulWalletModule.sol";
import {Errors} from "../libraries/Errors.sol";

abstract contract SoulWalletModuleManager is
    ISoulWalletModuleManager,
    ModuleManager
{
    function installModule(bytes calldata moduleAndData) external override {
        _onlyModule();
        _addModule(moduleAndData);
    }

    function _addModule(bytes calldata moduleAndData) internal {
         address moduleAddress = address(bytes20(moduleAndData[:20]));
        ISoulWalletModule aModule = ISoulWalletModule(moduleAddress);
        if (!aModule.supportsInterface(type(ISoulWalletModule).interfaceId)) {
            revert Errors.MODULE_NOT_SUPPORT_INTERFACE();
        }
        bytes4[] memory requiredFunctions = aModule.requiredFunctions();
        if (requiredFunctions.length == 0) {
            revert Errors.MODULE_SELECTORS_EMPTY();
        }
        _installModule(
            address(bytes20(moduleAndData[:20])),
            moduleAndData[20:],
            requiredFunctions
        );

    }
}
