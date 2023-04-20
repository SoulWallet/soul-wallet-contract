// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../libraries/CallHelper.sol";

interface IModule {
    enum HookType {
        PreHook,
        PostHook
    }

    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function supportsMethod(bytes4 methodId) external view returns (CallHelper.CallType);
    function supportsHook(HookType hookType) external view returns (CallHelper.CallType);
    function preHook(address target, uint256 value, bytes memory data) external;
    function postHook(address target, uint256 value, bytes memory data) external;
}
