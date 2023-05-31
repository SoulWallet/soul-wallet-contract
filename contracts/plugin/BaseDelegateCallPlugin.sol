// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./BasePlugin.sol";
import "../interfaces/ISoulWallet.sol";

abstract contract BaseDelegateCallPlugin is BasePlugin {
    event PluginInit(address indexed plugin);
    event PluginDeInit(address indexed plugin);

    bytes32 internal immutable PLUGIN_SLOT;

    constructor(bytes32 pluginSlot) {
        PLUGIN_SLOT = pluginSlot;
    }

    function _wallet() internal view override returns (address wallet) {
        wallet = address(this);
    }

    function inited() internal view virtual returns (bool);

    function walletInit(bytes calldata data) external override onlyDelegateCall {
        address wallet = _wallet();
        if (!inited()) {
            if (!ISoulWallet(wallet).isAuthorizedPlugin(DEPLOY_ADDRESS)) {
                revert("not authorized plugin");
            }
            _init(data);
            emit PluginInit(DEPLOY_ADDRESS);
        }
    }

    function walletDeInit() external override onlyDelegateCall {
        address wallet = _wallet();
        if (inited()) {
            if (ISoulWallet(wallet).isAuthorizedPlugin(DEPLOY_ADDRESS)) {
                revert("authorized plugin");
            }
            _deInit();
            emit PluginDeInit(DEPLOY_ADDRESS);
        }
    }

    function supportsHook() external pure override returns (uint8 hookType, CallHelper.CallType callType) {
        hookType = _supportsHook();
        callType = CallHelper.CallType.DelegateCall;
    }
}
