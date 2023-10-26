// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title Plugin Storage Interface
 * @dev This interface defines the functionalities to store and load data for plugins
 */
interface IPluginStorage {
    /**
     * @notice Store data for a plugin
     * @param key The key under which the value should be stored
     * @param value The value to be stored
     */
    function pluginDataStore(bytes32 key, bytes calldata value) external;

    /**
     * @notice Load data for a specific plugin using a key
     * @param plugin The address of the plugin for which data should be loaded
     * @param key The key under which the data is stored
     * @return The data stored under the given key for the specified plugin
     */
    function pluginDataLoad(address plugin, bytes32 key) external view returns (bytes memory);
}
