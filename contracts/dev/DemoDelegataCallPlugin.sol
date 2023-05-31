// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../plugin/BaseDelegateCallPlugin.sol";
import "../libraries/CallHelper.sol";

contract DemoDelegataCallPlugin is BaseDelegateCallPlugin {
    bool registry;

    event OnGuardHook();
    event OnPreHook();
    event OnPostHook();

    constructor() BaseDelegateCallPlugin(keccak256("UNUSEDSLOT")) {}

    function _supportsHook() internal pure override returns (uint8 hookType) {
        hookType = GUARD_HOOK | PRE_HOOK | POST_HOOK;
    }

    function guardHook(UserOperation calldata userOp, bytes32 userOpHash) external override onlyDelegateCall {
        (userOp, userOpHash);
        emit OnGuardHook();
    }

    function preHook(address target, uint256 value, bytes calldata data) external override onlyDelegateCall {
        (target, value, data);
        emit OnPreHook();
    }

    function postHook(address target, uint256 value, bytes calldata data) external override onlyDelegateCall {
        (target, value, data);
        emit OnPostHook();
    }

    function inited() internal view virtual override returns (bool) {
        return registry;
    }

    function _init(bytes calldata data) internal virtual override onlyDelegateCall {
        (data);
        registry = true;
    }

    function _deInit() internal virtual override onlyDelegateCall {
        registry = false;
    }
}
