// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../interfaces/IPlugin.sol";
import "../interfaces/ISoulWallet.sol";

abstract contract BasePlugin is IPlugin {
    event PluginInit(address indexed wallet);
    event PluginDeInit(address indexed wallet);

    bytes32 internal immutable PLUGIN_SLOT;

    // use immutable to avoid delegatecall to change the value
    address private immutable DEPLOY_ADDRESS;

    constructor(bytes32 pluginSlot) {
        PLUGIN_SLOT = pluginSlot;
        DEPLOY_ADDRESS = address(this);
    }

    function sender() internal view returns (address) {
        return msg.sender;
    }

    modifier onlyCall(){
        require(address(this) == DEPLOY_ADDRESS, "only call");
        _;
    }

    modifier onlyDelegateCall() {
        require(address(this) != DEPLOY_ADDRESS, "only delegate call");
        _;
    }

    function emptySlot(address wallet) internal view virtual returns (bool);

    function walletInit(bytes calldata data) external override {
        address _sender = sender();
        bool _emptySlot = emptySlot(_sender);
        if (_emptySlot) {
            if (!ISoulWallet(_sender).isAuthorizedPlugin(DEPLOY_ADDRESS)) {
                revert("not authorized plugin");
            }
            _init(data);
            emit PluginInit(_sender);
        }
    }

    function walletDeInit() external override {
        address _sender = sender();
        bool _emptySlot = emptySlot(_sender);
        if (!_emptySlot) {
            if (ISoulWallet(_sender).isAuthorizedPlugin(DEPLOY_ADDRESS)) {
                revert("authorized plugin");
            }
            _deInit();
            emit PluginDeInit(_sender);
        }
    }

    function _init(bytes calldata data) internal virtual;

    function _deInit() internal virtual;

    function supportsInterface(
        bytes4 interfaceId
    ) external view override returns (bool) {
        return interfaceId == type(IPlugin).interfaceId;
    }
}
