// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "../interfaces/IPlugin.sol";
import "../interfaces/ISoulWallet.sol";
import "../interfaces/IPluginManager.sol";

/**
 * @title BasePlugin
 * @dev Abstract base contract for creating plugins. Implements the IPlugin interface.
 */
abstract contract BasePlugin is IPlugin {
    /**
     * @dev Bit flags for specifying supported hook types
     */
    uint8 internal constant GUARD_HOOK = 1 << 0;
    uint8 internal constant PRE_HOOK = 1 << 1;
    uint8 internal constant POST_HOOK = 1 << 2;
    /**
     * @dev Emitted when the plugin is initialized for a wallet
     */

    event PluginInit(address indexed wallet);
    /**
     * @dev Emitted when the plugin is deinitialized for a wallet
     */
    event PluginDeInit(address indexed wallet);
    /**
     * @dev Internal utility function to get the sender of the transaction
     */

    function _sender() internal view returns (address) {
        return msg.sender;
    }
    /**
     * @dev Virtual function for plugin-specific initialization logic
     */

    function _init(bytes calldata data) internal virtual;
    /**
     * @dev Virtual function for plugin-specific de-initialization logic
     */
    function _deInit() internal virtual;
    /**
     * @dev Specifies the hook types this plugin supports
     */
    function _supportsHook() internal pure virtual returns (uint8 hookType);
    /**
     * @dev Utility function to retrieve the address of the wallet invoking the plugin
     */

    function _wallet() internal view returns (address wallet) {
        wallet = _sender();
    }
    /**
     * @notice Checks if this contract implements a specific interface
     */

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IPlugin).interfaceId;
    }
    /**
     * @dev Checks if the plugin is initialized for the given wallet
     */

    function inited(address wallet) internal view virtual returns (bool);
    /**
     * @notice Initializes the plugin for a wallet
     */

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
    /**
     * @notice De-initializes the plugin for a wallet
     */

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
