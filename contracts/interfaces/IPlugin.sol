// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../libraries/CallHelper.sol";
import "../../account-abstraction/contracts/interfaces/UserOperation.sol";
import "./IPluggable.sol";

interface IPlugin is IPluggable {

    enum HookType {
        GuardHook,
        PreHook,
        PostHook
    }

    function getHookCallType(HookType hookType) external view returns (CallHelper.CallType calltype);
    function isHookCall(HookType hookType) external view returns (bool);
    
    function guardHook(UserOperation calldata userOp, bytes32 userOpHash) external;
    function preHook(address target, uint256 value, bytes calldata data) external;
    function postHook(address target, uint256 value, bytes calldata data) external;
}