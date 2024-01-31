// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {AuthoritySnippet} from "../snippets/Authority.sol";
import {ModuleManagerSnippet} from "../snippets/ModuleManager.sol";

abstract contract ModuleInstaller is AuthoritySnippet, ModuleManagerSnippet {
    /**
     * @dev install a module
     * @param moduleAndData [0:20]: module address, [20:]: module init data
     * @param selectors function selectors that the module is allowed to call
     */
    function installModule(bytes calldata moduleAndData, bytes4[] calldata selectors) external {
        pluginManagementAccess();
        _installModule(address(bytes20(moduleAndData[:20])), moduleAndData[20:], selectors);
    }
}
