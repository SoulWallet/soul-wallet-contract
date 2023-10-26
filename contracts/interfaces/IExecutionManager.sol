// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title IExecutionManager
 * @dev Interface for executing transactions or batch of transactions
 * The execution can be a single transaction or multiple transactions in sequence
 */
interface IExecutionManager {
    /**
     * @notice Executes a single transaction
     * @dev This can be invoked directly by the owner or by an entry point
     *
     * @param dest The destination address for the transaction
     * @param value The amount of Ether (in wei) to transfer along with the transaction. Can be 0 for non-ETH transfers
     * @param func The function call data to be executed
     */
    function execute(address dest, uint256 value, bytes calldata func) external;

    /**
     * @notice Executes a sequence of transactions with the same Ether value for each
     * @dev All transactions in the batch will carry 0 Ether value
     * @param dest An array of destination addresses for each transaction in the batch
     * @param func An array of function call data for each transaction in the batch
     */
    function executeBatch(address[] calldata dest, bytes[] calldata func) external;

    /**
     * @notice Executes a sequence of transactions with specified Ether values for each
     * @dev The values for Ether transfer are specified for each transaction
     * @param dest An array of destination addresses for each transaction in the batch
     * @param value An array of amounts of Ether (in wei) to transfer for each transaction in the batch
     * @param func An array of function call data for each transaction in the batch
     */
    function executeBatch(address[] calldata dest, uint256[] calldata value, bytes[] calldata func) external;
}
