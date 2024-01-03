// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {HookManager} from "@soulwallet-core/contracts/base/HookManager.sol";
import {ISoulWalletHookManager} from "../interfaces/ISoulWalletHookManager.sol";

abstract contract SoulWalletHookManager is ISoulWalletHookManager, HookManager {
    function _installHook(bytes calldata hookAndDataWithFlag) internal virtual {
        _installHook(
            address(bytes20(hookAndDataWithFlag[:20])),
            hookAndDataWithFlag[20:hookAndDataWithFlag.length - 1],
            uint8(bytes1((hookAndDataWithFlag[hookAndDataWithFlag.length - 1:hookAndDataWithFlag.length])))
        );
    }

    function installHook(bytes calldata hookAndData, uint8 capabilityFlags) external virtual override {
        pluginManagementAccess();
        _installHook(address(bytes20(hookAndData[:20])), hookAndData[20:], capabilityFlags);
    }
}
