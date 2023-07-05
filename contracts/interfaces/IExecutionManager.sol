// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

interface IExecutionManager {
    /**
     * execute a transaction (called directly from owner, or by entryPoint)
     */
    function execute(address dest, uint256 value, bytes calldata func) external;

    /**
     * execute a sequence of transactions
     */
    function executeBatch(address[] calldata dest, bytes[] calldata func) external;

    /**
     * execute a sequence of transactions
     */
    function executeBatch(address[] calldata dest, uint256[] calldata value, bytes[] calldata func) external;
}
