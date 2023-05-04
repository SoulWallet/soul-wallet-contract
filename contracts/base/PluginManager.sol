// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../safeLock/SafeLock.sol";
import "../interfaces/IPluginManager.sol";
import "../interfaces/IPlugin.sol";
import "../libraries/DecodeCalldata.sol";
import "../trustedModuleManager/ITrustedModuleManager.sol";
import "./OwnerManager.sol";
import "../libraries/CallHelper.sol";

abstract contract PluginManager is IPluginManager, SafeLock, AccountManager {
    using DecodeCalldata for bytes;
    ITrustedModuleManager public immutable trustedModuleManager;
    bytes32 private constant MODULE_TIMELOCK_TAG = keccak256("soulwallet.contracts.ModuleManager.MODULE_TIMELOCK_TAG");

    constructor(uint64 _safeLockPeriod, ITrustedModuleManager _trustedModuleManager) SafeLock("soulwallet.contracts.ModuleManager.slot", _safeLockPeriod){
        trustedModuleManager = _trustedModuleManager;
    }

    function addModule(ModuleInfo calldata module) external {
        _requireFromEntryPointOrOwner();

        // check if the module is trusted
        if(trustedModuleManager.isTrustedModule(address(module.module)) == false){
            // check if the module is no side-effect
            require(
                module.postHook == false &&
                module.preHook == false &&
                module.methodsInfo.length > 0
            );
            for(uint i = 0; i < module.methodsInfo.length; i++){
                require(module.methodsInfo[i].callType == CallHelper.CallType.STATICCALL, "not static call");
            }
        }

        // #ADD MODULE TO STORAGE

        emit ModuleAdded(address(module.module), module.preHook, module.postHook, module.methodsInfo);

    }

    function _getTimeLockTag(address module) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(MODULE_TIMELOCK_TAG, module));
    }

    function removeModule(address module) external {
        _requireFromEntryPointOrOwner();

        bool pureModule = true;
        if(pureModule){
            // can removeModule directly if the module is `pure module`
            emit ModuleRemoved(module);
        }else{
            // if the module is not `pure module`, need ues safeLock to removeModule
            lock(_getTimeLockTag(module));
            emit ModuleRemove(module);
        }
    }

    function cancelRemoveModule(address module) external {
        _requireFromEntryPointOrOwner();
        cancelLock(_getTimeLockTag(module));
        emit ModuleCancelRemoved(module);
    }

    function confirmRemoveModule(address module) external {
        _requireFromEntryPointOrOwner();
        unlock(_getTimeLockTag(module));
        emit ModuleRemoved(module);
    }

    function getModules() external view override returns (ModuleInfo[] memory modules) {
         
    }


    function preHook(
        address target,
        uint256 value,
        bytes memory data
    ) internal {
        (target, value, data);
    }

    function postHook(
        address target,
        uint256 value,
        bytes memory data
    ) internal {
        (target, value, data);
    }


    function _getModulesByMethodId(
        bytes4 methodId
    ) private view returns (address module, CallHelper.CallType callType) {
        (methodId);
        revert("not implemented");
    }


    function _beforeFallback() internal virtual { 
        bytes4 methodId = msg.data.decodeMethodId();
        (address module, CallHelper.CallType callType) = _getModulesByMethodId(methodId);
        CallHelper.callWithoutReturnData(callType, module, msg.data);
    }
    
}
