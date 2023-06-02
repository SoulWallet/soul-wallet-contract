// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./BasePlugin.sol";
import "../interfaces/ISoulWallet.sol";

abstract contract BaseCallPlugin is BasePlugin {
    event PluginInit(address indexed wallet);
    event PluginDeInit(address indexed wallet);

    function _wallet() internal view override returns (address wallet) {
        wallet = _sender();
    }

    function inited(address wallet) internal view virtual returns (bool);

    function walletInit(bytes calldata data) external override onlyCall {
        address wallet = _wallet();
        if (!inited(wallet)) {
            if (!ISoulWallet(wallet).isAuthorizedPlugin(address(this))) {
                revert("not authorized plugin");
            }
            _init(data);
            emit PluginInit(wallet);
        }
    }

    function walletDeInit() external override onlyCall {
        address wallet = _wallet();
        if (inited(wallet)) {
            if (ISoulWallet(wallet).isAuthorizedPlugin(address(this))) {
                revert("authorized plugin");
            }
            _deInit();
            emit PluginDeInit(wallet);
        }
    }

    function supportsHook() external pure override returns (uint8 hookType, uint8 callType) {
        hookType = _supportsHook();
        callType = CALL;
    }
}
