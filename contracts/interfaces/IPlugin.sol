// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "@account-abstraction/contracts/interfaces/UserOperation.sol";
import "./IPluggable.sol";

interface IPlugin is IPluggable {
    /**
     * @dev
     * hookType structure:
     * GuardHook: 1<<0
     * PreHook:   1<<1
     * PostHook:  1<<2
     */
    function supportsHook() external pure returns (uint8 hookType);

    /**
     * @dev For flexibility, guardData does not participate in the userOp signature verification.
     *      Plugins must revert when they do not need guardData but guardData.length > 0(for security reasons)
     */
    function guardHook(UserOperation calldata userOp, bytes32 userOpHash, bytes calldata guardData) external;

    function preHook(address target, uint256 value, bytes calldata data) external;

    function postHook(address target, uint256 value, bytes calldata data) external;
}
