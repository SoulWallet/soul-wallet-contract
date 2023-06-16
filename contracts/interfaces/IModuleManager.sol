// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./IModule.sol";

interface IModuleManager {
    event ModuleAdded(address indexed module);
    event ModuleRemoved(address indexed module);
    event ModuleRemovedWithError(address indexed module);

    function addModule(bytes calldata moduleAndData) external;

    function removeModule(address) external;

    function isAuthorizedModule(address module) external returns (bool);

    function listModule() external view returns (address[] memory modules, bytes4[][] memory selectors);

    function executeFromModule(address dest, uint256 value, bytes calldata func) external;
}
