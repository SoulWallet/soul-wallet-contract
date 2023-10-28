// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "../authority/Authority.sol";
import "./PluginManager.sol";
import "../interfaces/IExecutionManager.sol";

/**
 * @title ExecutionManager
 * @notice Manages the execution of transactions and batches of transactions
 * @dev Inherits functionality from IExecutionManager, Authority, and PluginManager
 */
abstract contract ExecutionManager is IExecutionManager, Authority, PluginManager {
    /**
     * @notice Execute a transaction
     * @param dest The destination address for the transaction
     * @param value The amount of ether to be sent with the transaction
     * @param func The calldata for the transaction
     */
    function execute(address dest, uint256 value, bytes calldata func) external override onlyEntryPoint {
        _call(dest, value, func);
    }

    /**
     * @notice Execute a sequence of transactions without any associated ether
     * @param dest List of destination addresses for each transaction
     * @param func List of calldata for each transaction
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
     * @notice Execute a sequence of transactions, each potentially having associated ether
     * @param dest List of destination addresses for each transaction
     * @param value List of ether amounts for each transaction
     * @param func List of calldata for each transaction
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

    /**
     * @dev Internal function to handle the call logic
     * @param target Address of the target contract
     * @param value Ether to be sent with the transaction
     * @param data Calldata for the transaction
     */
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
