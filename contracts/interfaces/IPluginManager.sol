// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./IModule.sol";
import "../libraries/CallHelper.sol";

interface IModuleManager {
    struct MethodsInfo{
        bytes4 methodId;
        CallHelper.CallType callType;
    }
    struct ModuleInfo {
        IModule module;
        bool preHook;
        bool postHook;
        MethodsInfo[] methodsInfo;
    }
    event ModuleAdded(address indexed module, bool preHook, bool postHook, MethodsInfo[] methodsInfo);
    event ModuleRemove(address indexed module);
    event ModuleCancelRemoved(address indexed module);
    event ModuleRemoved(address indexed module);
    function addModule(ModuleInfo calldata module) external;
    function removeModule(address module) external;
    function cancelRemoveModule(address module) external;
    function confirmRemoveModule(address module) external;
    function getModules() external view returns (ModuleInfo[] memory modules);
}
