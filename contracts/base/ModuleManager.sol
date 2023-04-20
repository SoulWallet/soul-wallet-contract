// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../safeLock/SafeLock.sol";
import "../interfaces/IModuleManager.sol";
import "../interfaces/IModule.sol";
import "../libraries/DecodeCalldata.sol";
import "../trustedModuleManager/ITrustedModuleManager.sol";
import "./FallbackModuleManager.sol";

abstract contract ModuleManager is IModuleManager,SafeLock,FallbackModuleManager {
    using DecodeCalldata for bytes;
    ITrustedModuleManager public immutable trustedModuleManager;
    bytes32 private constant MODULE_TIMELOCK_TAG = keccak256("soulwallet.contracts.ModuleManager.MODULE_TIMELOCK_TAG");

    constructor(uint64 _safeLockPeriod, ITrustedModuleManager _trustedModuleManager) SafeLock("soulwallet.contracts.ModuleManager.slot", _safeLockPeriod){
        trustedModuleManager = _trustedModuleManager;
    }

    function addModule(
        IModule module,
        bytes4[] calldata staticCallMethodId,
        bytes4[] calldata delegateCallMethodId,
        bytes4[] calldata hookId,
        bytes memory data
    ) public {
        (module, staticCallMethodId, delegateCallMethodId, hookId, data);
        require(trustedModuleManager.isTrustedModule(address(module)), "not trusted module");
    }

    function _getTimeLockTag(address module) private view returns (bytes32) {
        return keccak256(abi.encodePacked(MODULE_TIMELOCK_TAG, module));
    }

    function removeModule(address module) public {
        (module);
        lock(_getTimeLockTag(module));
    }
    function confirmremoveModule(address module) public {
        (module);
        unlock(_getTimeLockTag(module));
    }

    function getModules() public view returns (address[] memory modules) {
        return new address[](0);
    }

    function getModulesBeforeExecution()
        public
        view
        returns (address[] memory modules, bool[] memory isStatic)
    {
        return (new address[](0), new bool[](0));
    }

    function beforeExecution(
        address target,
        uint256 value,
        bytes memory data
    ) internal {
        (target, value, data);
    }

    function getModulesAfterExecution()
        public
        view
        returns (address[] memory modules, bool[] memory isStatic)
    {
        return (new address[](0), new bool[](0));
    }

    function afterExecution(
        address target,
        uint256 value,
        bytes memory data
    ) internal {
        (target, value, data);
    }

    function _getModulesByMethodId(
        bytes4 methodId
    ) private view returns (address module, bool isStatic) {
        (methodId);
        return (address(0), false);
    }

    function _beforeFallback() internal virtual override {
        super._beforeFallback();
        bytes4 methodId = msg.data.decodeMethodId();
        (address module, bool isStatic) = _getModulesByMethodId(methodId);
        if (module != address(0)) {
            if (isStatic) {
                (bool success, bytes memory result) = module.staticcall(
                    msg.data
                );
                if (!success) {
                    assembly {
                        revert(add(result, 32), mload(result))
                    }
                }
                assembly {
                    return(add(result, 32), mload(result))
                }
            } else {
                (bool success, bytes memory result) = module.delegatecall(
                    msg.data
                );
                if (!success) {
                    assembly {
                        revert(add(result, 32), mload(result))
                    }
                }
                assembly {
                    return(add(result, 32), mload(result))
                }
            }
        }
    }
}
