// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

struct Execution {
    // The target contract for account to execute.
    address target;
    // The value for the execution.
    uint256 value;
    // The call data for the execution.
    bytes data;
}

interface IStandardExecutor {
    /// @dev Standard execute method.
    /// @param target The target contract for account to execute.
    /// @param value The value for the execution.
    /// @param data The call data for the execution.
    function execute(address target, uint256 value, bytes calldata data) external payable;

    /// @dev Standard executeBatch method.
    /// @param executions The array of executions.
    function executeBatch(Execution[] calldata executions) external payable;
}
