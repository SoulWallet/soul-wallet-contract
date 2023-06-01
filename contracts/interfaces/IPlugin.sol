// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "@account-abstraction/contracts/interfaces/UserOperation.sol";
import "./IPluggable.sol";

interface IPlugin is IPluggable {
    /**
     * @dev
     * hookType structure:
     * 0b1: GuardHook
     * 0b10: PreHook
     * 0b100: PostHook
     *
     * callType structure:
     * 0: call
     * 1: delegatecall
     * ... reserved for future use
     */
    function supportsHook() external pure returns (uint8 hookType, uint8 callType);

    function guardHook(UserOperation calldata userOp, bytes32 userOpHash) external;
    function preHook(address target, uint256 value, bytes calldata data) external;
    function postHook(address target, uint256 value, bytes calldata data) external;
}
