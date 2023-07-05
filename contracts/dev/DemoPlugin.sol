// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../plugin/BasePlugin.sol";

contract DemoPlugin is BasePlugin {
    mapping(address => bool) registry;

    event OnGuardHook();
    event OnPreHook();
    event OnPostHook();

    function _supportsHook() internal pure override returns (uint8 hookType) {
        hookType = GUARD_HOOK | PRE_HOOK | POST_HOOK;
    }

    function guardHook(UserOperation calldata userOp, bytes32 userOpHash, bytes calldata guardData)
        external
        override
    {
        (userOp, userOpHash, guardData);
        emit OnGuardHook();
    }

    function preHook(address target, uint256 value, bytes calldata data) external override {
        (target, value, data);
        emit OnPreHook();
    }

    function postHook(address target, uint256 value, bytes calldata data) external override {
        (target, value, data);
        emit OnPostHook();
    }

    function inited(address wallet) internal view virtual override returns (bool) {
        return registry[wallet];
    }

    function _init(bytes calldata data) internal virtual override {
        (data);
        registry[_wallet()] = true;
    }

    function _deInit() internal virtual override {
        delete registry[_wallet()];
    }
}
