// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "./IPlugin.sol";

/**
 * @title Plugin Manager Interface
 * @dev This interface provides functionalities for adding, removing, and querying plugins
 */
interface IPluginManager {
    event PluginAdded(address indexed plugin);
    event PluginRemoved(address indexed plugin);
    event PluginRemovedWithError(address indexed plugin);

    /**
     * @notice Add a new plugin along with its initialization data
     * @param pluginAndData The plugin address concatenated with its initialization data
     */
    function addPlugin(bytes calldata pluginAndData) external;

    /**
     * @notice Remove a plugin from the system
     * @param plugin The address of the plugin to be removed
     */
    function removePlugin(address plugin) external;

    /**
     * @notice Checks if a plugin is authorized
     * @param plugin The address of the plugin to check
     * @return True if the plugin is authorized, otherwise false
     */
    function isAuthorizedPlugin(address plugin) external returns (bool);

    /**
     * @notice List all plugins of a specific hook type
     * @param hookType The type of the hook for which to list plugins
     * @return plugins An array of plugin addresses corresponding to the hookType
     */
    function listPlugin(uint8 hookType) external view returns (address[] memory plugins);
}
