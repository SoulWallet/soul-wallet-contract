// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../interfaces/IModuleManager.sol";
import "../interfaces/IModule.sol";
import "../libraries/DecodeCalldata.sol";

abstract contract ModuleManager is IModuleManager {
    using DecodeCalldata for bytes;

    function addModule(
        IModule module,
        bytes4[] calldata staticCallMethodId,
        bytes4[] calldata delegateCallMethodId,
        bytes4[] calldata hookId,
        bytes memory data
    ) public {
        (module, staticCallMethodId, delegateCallMethodId, hookId, data);
    }

    function removeModule(address module) public {
        (module);
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

    function getModulesByMethodId(
        bytes4 methodId
    ) public view returns (address module, bool isStatic) {
        (methodId);
        return (address(0), false);
    }

    fallback() external payable {
        bytes4 methodId = msg.data.decodeMethodId();
        (address module, bool isStatic) = getModulesByMethodId(methodId);
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
