// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./IModule.sol";

interface IModuleManager {
    struct Module {
        IModule module;
        bytes4[] selectors;
        bytes initData;
    }

    event ModuleAdded(address indexed module, bytes4[] selectors);
    event ModuleRemoved(address indexed module);
    event ModuleRemovedWithError(address indexed module);

    // function addModule(Module) external;
    // function removeModule(address module) external;

    function isAuthorizedModule(address module) external returns (bool);

    function listModule()
        external
        view
        returns (address[] memory modules, bytes4[][] memory selectors);

    function execFromModule(bytes calldata data) external;
}
