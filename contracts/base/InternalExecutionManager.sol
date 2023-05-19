// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

abstract contract InternalExecutionManager {
    bytes4 internal constant FUNC_EXECUTE = bytes4(keccak256("execute(address,uint256,bytes)"));
    bytes4 internal constant FUNC_EXECUTE_BATCH = bytes4(keccak256("executeBatch(address[],bytes[])"));
    bytes4 internal constant FUNC_EXECUTE_BATCH_VALUE = bytes4(keccak256("executeBatch(address[],uint256[],bytes[])"));

    /**
     * execute a transaction (called directly from owner, or by entryPoint)
     */
    function _execute(address dest, uint256 value, bytes memory func) internal virtual;

    /**
     * execute a sequence of transactions
     */
    function _executeBatch(address[] memory dest, bytes[] memory func) internal virtual;

    /**
     * execute a sequence of transactions
     */
    function _executeBatch(address[] memory dest, uint256[] memory value, bytes[] memory func) internal virtual;
}
