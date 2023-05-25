// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../plugin/BasePlugin.sol";
import "../libraries/CallHelper.sol";

contract DemoPlugin is BasePlugin {
    mapping(address => bool) registry;

    event OnGuardHook();
    event OnPreHook();
    event OnPostHook();

    constructor() BasePlugin(keccak256("UNUSEDSLOT")) {}

    function getHookCallType(HookType hookType) external view override returns (CallHelper.CallType calltype) {
        return CallHelper.CallType.Call;
    }

    function isHookCall(HookType hookType) external view override returns (bool) {
        return true;
    }

    function guardHook(UserOperation calldata userOp, bytes32 userOpHash) external override {
        emit OnGuardHook();
    }

    function preHook(address target, uint256 value, bytes calldata data) external override {
        emit OnPreHook();
    }

    function postHook(address target, uint256 value, bytes calldata data) external override {
        emit OnPostHook();
    }

    function inited(address wallet) internal view virtual override returns (bool) {
        return registry[wallet];
    }

    function _init(bytes calldata data) internal virtual override {
        registry[sender()] = true;
    }

    function _deInit() internal virtual override {
        delete registry[sender()];
    }
}
