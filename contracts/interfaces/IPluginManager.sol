// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./IPlugin.sol";

interface IPluginManager {
    event PluginAdded(address indexed plugin);
    event PluginRemoved(address indexed plugin);
    event PluginRemovedWithError(address indexed plugin);

    function addPlugin(bytes calldata pluginAndData) external;

    function removePlugin(address plugin) external;

    function isAuthorizedPlugin(address plugin) external returns (bool);

    function listPlugin(uint8 hookType) external view returns (address[] memory plugins);
}
