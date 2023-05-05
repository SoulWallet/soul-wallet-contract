// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./IPlugin.sol";
import "../libraries/CallHelper.sol";

interface IPluginManager {
    event PluginAdded(IPlugin indexed plugin);
    event PluginRemoved(IPlugin indexed plugin);
    function addPlugin(IPlugin plugin) external;
    function removePlugin(IPlugin plugin) external;
    function listPlugin() external view returns (IPlugin[] memory plugins);
    function execDelegateCall(IPlugin target,bytes memory data) external;
}