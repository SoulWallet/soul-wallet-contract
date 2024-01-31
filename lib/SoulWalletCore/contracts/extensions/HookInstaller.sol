// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {AuthoritySnippet} from "../snippets/Authority.sol";
import {HookManagerSnippet} from "../snippets/HookManager.sol";

abstract contract HookInstaller is AuthoritySnippet, HookManagerSnippet {
    /**
     * @dev Install a hook
     * @param hookAndData [0:20]: hook address, [20:]: hook data
     * @param capabilityFlags Capability flags for the hook
     */
    function installHook(bytes calldata hookAndData, uint8 capabilityFlags) external {
        pluginManagementAccess();
        _installHook(address(bytes20(hookAndData[:20])), hookAndData[20:], capabilityFlags);
    }
}
