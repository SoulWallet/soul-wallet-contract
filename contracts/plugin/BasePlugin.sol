// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../interfaces/IPlugin.sol";
import "../interfaces/ISoulWallet.sol";
import "../interfaces/IPluginManager.sol";

abstract contract BasePlugin is IPlugin {
    uint8 internal constant GUARD_HOOK = 1 << 0;
    uint8 internal constant PRE_HOOK = 1 << 1;
    uint8 internal constant POST_HOOK = 1 << 2;

    event PluginInit(address indexed wallet);
    event PluginDeInit(address indexed wallet);

    function _sender() internal view returns (address) {
        return msg.sender;
    }

    function _init(bytes calldata data) internal virtual;

    function _deInit() internal virtual;

    function _supportsHook() internal pure virtual returns (uint8 hookType);

    function _wallet() internal view returns (address wallet) {
        wallet = _sender();
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IPlugin).interfaceId;
    }

    function inited(address wallet) internal view virtual returns (bool);

    function walletInit(bytes calldata data) external override {
        address wallet = _wallet();
        if (!inited(wallet)) {
            if (!ISoulWallet(wallet).isAuthorizedPlugin(address(this))) {
                revert("not authorized plugin");
            }
            _init(data);
            emit PluginInit(wallet);
        }
    }

    function walletDeInit() external override {
        address wallet = _wallet();
        if (inited(wallet)) {
            if (ISoulWallet(wallet).isAuthorizedPlugin(address(this))) {
                revert("authorized plugin");
            }
            _deInit();
            emit PluginDeInit(wallet);
        }
    }

    function supportsHook() external pure override returns (uint8 hookType) {
        hookType = _supportsHook();
    }
}
