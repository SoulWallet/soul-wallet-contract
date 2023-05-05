// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../libraries/CallHelper.sol";
import "../../account-abstraction/contracts/interfaces/UserOperation.sol";

interface IPlugin {

    enum HookType {
        GuardHook,
        PreHook,
        PostHook
    }

    struct SupportsHook {
        CallHelper.CallType guardHook;
        CallHelper.CallType preHook;
        CallHelper.CallType postHook;
    }

    function supportsHook() external view returns (SupportsHook memory);
    
    function guardHook(UserOperation calldata userOp) external;
    function preHook(address target, uint256 value, bytes calldata data) external;
    function postHook(address target, uint256 value, bytes calldata data) external;
}