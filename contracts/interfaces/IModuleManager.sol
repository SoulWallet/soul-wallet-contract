// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./IModule.sol";

interface IModuleManager {
    event ModuleAdded(address module, bytes4[] staticCallMethodId, bytes4[] delegateCallMethodId, bytes4[] hookId);
    event ModuleRemoved(address module);
    function addModule(IModule module, bytes4[] calldata staticCallMethodId, bytes4[] calldata delegateCallMethodId, bytes4[] calldata hookId, bytes memory data) external;
    function removeModule(address module) external;
    function getModules() external view returns (address[] memory modules);
    function getModulesBeforeExecution() external view returns (address[] memory modules,bool[] memory isStatic);
    function getModulesAfterExecution() external view returns (address[] memory modules,bool[] memory isStatic);
    function getModulesByMethodId(bytes4 methodId) external view returns (address module,bool isStatic);
}
