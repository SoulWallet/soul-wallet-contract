// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@account-abstraction/contracts/interfaces/UserOperation.sol";
import "./IPluggable.sol";

/**
 * @title Plugin Interface
 * @dev This interface provides functionalities for hooks and interactions of plugins within a wallet or contract
 */
interface IPlugin is IPluggable {
    /**
     * @notice Specifies the types of hooks a plugin supports
     * @return hookType An 8-bit value where:
     *         - GuardHook is represented by 1<<0
     *         - PreHook is represented by 1<<1
     *         - PostHook is represented by 1<<2
     */
    function supportsHook() external pure returns (uint8 hookType);

    /**
     * @notice A hook that guards the user operation
     * @dev For security, plugins should revert when they do not need guardData but guardData.length > 0
     * @param userOp The user operation being performed
     * @param userOpHash The hash of the user operation
     * @param guardData Additional data for the guard
     */
    function guardHook(UserOperation calldata userOp, bytes32 userOpHash, bytes calldata guardData) external;

    /**
     * @notice A hook that's executed before the actual operation
     * @param target The target address of the operation
     * @param value The amount of ether (in wei) involved in the operation
     * @param data The calldata for the operation
     */
    function preHook(address target, uint256 value, bytes calldata data) external;

    /**
     * @notice A hook that's executed after the actual operation
     * @param target The target address of the operation
     * @param value The amount of ether (in wei) involved in the operation
     * @param data The calldata for the operation
     */
    function postHook(address target, uint256 value, bytes calldata data) external;
}
