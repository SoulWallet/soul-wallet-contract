// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./IPlugin.sol";
import "../libraries/CallHelper.sol";

interface IPluginManager {
    struct Plugin {
        IPlugin plugin;
        bytes initData;
    }
    event PluginAdded(address indexed plugin);
    event PluginRemoved(address indexed plugin);
    event PluginRemovedWithError(address indexed plugin);

    // function addPlugin(Plugin plugin) external;
    // function removePlugin(address plugin) external;

    function isAuthorizedPlugin(address plugin) external returns (bool);

    function listPlugin() external view returns (IPlugin[] memory plugins);

    function execDelegateCall(IPlugin target, bytes calldata data) external;
}
