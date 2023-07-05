// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../authority/Authority.sol";
import "./PluginManager.sol";
import "../interfaces/IExecutionManager.sol";

abstract contract ExecutionManager is IExecutionManager, Authority, PluginManager {
    /**
     * execute a transaction
     */
    function execute(address dest, uint256 value, bytes calldata func) external override onlyEntryPoint {
        _call(dest, value, func);
    }

    /**
     * execute a sequence of transactions
     */
    function executeBatch(address[] calldata dest, bytes[] calldata func) external override onlyEntryPoint {
        for (uint256 i = 0; i < dest.length;) {
            _call(dest[i], 0, func[i]);
            unchecked {
                i++;
            }
        }
    }

    /**
     * execute a sequence of transactions
     */
    function executeBatch(address[] calldata dest, uint256[] calldata value, bytes[] calldata func)
        external
        override
        onlyEntryPoint
    {
        for (uint256 i = 0; i < dest.length;) {
            _call(dest[i], value[i], func[i]);
            unchecked {
                i++;
            }
        }
    }

    function _call(address target, uint256 value, bytes memory data) private executeHook(target, value, data) {
        assembly ("memory-safe") {
            let result := call(gas(), target, value, add(data, 0x20), mload(data), 0, 0)
            if iszero(result) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
        }
    }
}
