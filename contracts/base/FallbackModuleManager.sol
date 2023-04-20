// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../interfaces/IFallbackModuleManager.sol";
import "../interfaces/IFallbackModule.sol";
import "../libraries/DecodeCalldata.sol";
import "../trustedModuleManager/ITrustedModuleManager.sol";

abstract contract FallbackModuleManager is IFallbackModuleManager {
    using DecodeCalldata for bytes;

    function addFallbackModule(
        IFallbackModule module,
        bytes4[] calldata staticCallMethodId
    ) public {
        (module, staticCallMethodId);
    }

    function removeFallbackModule(address module) public {
        (module);
    }

    function getFallbackModules() public view returns (address[] memory modules) {
        return new address[](0);
    }

    function _getFallbackModulesByMethodId(
        bytes4 methodId
    ) private view returns (address module) {
        (methodId);
        return address(0);
    }

    function _beforeFallback() internal virtual {
        bytes4 methodId = msg.data.decodeMethodId();
        address module = _getFallbackModulesByMethodId(methodId);
        if (module != address(0)) {
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
            
        }
    }
}
