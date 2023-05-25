// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../interfaces/IPluginManager.sol";
import "../interfaces/IPlugin.sol";
import "../libraries/AccountStorage.sol";
import "../authority/Authority.sol";
import "../libraries/AddressLinkedList.sol";

abstract contract PluginManager is Authority, IPluginManager {
    using AddressLinkedList for mapping(address => address);

    bytes4 internal constant FUNC_ADD_PLUGIN = bytes4(keccak256("addPlugin(address,bytes)"));
    bytes4 internal constant FUNC_REMOVE_PLUGIN = bytes4(keccak256("removePlugin(address)"));

    function pluginsMapping() private view returns (mapping(address => address) storage plugins) {
        plugins = AccountStorage.layout().plugins;
    }

    function addPlugin(bytes calldata pluginAndData) internal {
        address moduleAddress = address(bytes20(pluginAndData[:20]));
        bytes memory initData = pluginAndData[20:];
        addPlugin(moduleAddress, initData);
    }

    function addPlugin(address pluginAddress, bytes memory initData) internal {
        IPlugin aPlugin = IPlugin(pluginAddress);
        require(IPlugin(aPlugin).supportsInterface(type(IPlugin).interfaceId), "unknown plugin");
        mapping(address => address) storage plugins = pluginsMapping();
        plugins.add(pluginAddress);
        //TODO call initdata necessary?
        emit PluginAdded(pluginAddress);
    }

    function removePlugin(address plugin) internal {
        mapping(address => address) storage plugins = pluginsMapping();
        plugins.remove(plugin);
        emit PluginRemoved(plugin);
    }

    function _isAuthorizedPlugin(address plugin) private returns (bool) {
        return pluginsMapping().isExist(plugin);
    }

    function isAuthorizedPlugin(address plugin) external override returns (bool) {
        return _isAuthorizedPlugin(plugin);
    }

    function listPlugin() external view override returns (address[] memory plugins) {
        mapping(address => address) storage _plugins = pluginsMapping();
        plugins = _plugins.list(AddressLinkedList.SENTINEL_ADDRESS, _plugins.size());
    }

    function guardHook(UserOperation calldata userOp, bytes32 userOpHash) internal returns (bool) {
        mapping(address => address) storage _plugins = pluginsMapping();
        address[] memory plugins = _plugins.list(AddressLinkedList.SENTINEL_ADDRESS, _plugins.size());
        for (uint256 i = 0; i < plugins.length; i++) {
            if (IPlugin(plugins[i]).isHookCall(IPlugin.HookType.GuardHook)) {
                (bool success,) = CallHelper.call(
                    IPlugin(plugins[i]).getHookCallType(IPlugin.HookType.GuardHook),
                    plugins[i],
                    abi.encodeCall(IPlugin.guardHook, (userOp, userOpHash))
                );
                if (!success) {
                    return false;
                }
            }
        }
        return true;
    }

    function preHook(address target, uint256 value, bytes memory data) internal {
        mapping(address => address) storage _plugins = pluginsMapping();
        address[] memory plugins = _plugins.list(AddressLinkedList.SENTINEL_ADDRESS, _plugins.size());
        for (uint256 i = 0; i < plugins.length; i++) {
            if (IPlugin(plugins[i]).isHookCall(IPlugin.HookType.PreHook)) {
                //TODO is getHookCallType necessary? call or d`elegatecall?
                (bool success,) = CallHelper.call(
                    IPlugin(plugins[i]).getHookCallType(IPlugin.HookType.PreHook),
                    plugins[i],
                    abi.encodeCall(IPlugin.preHook, (target, value, data))
                );
                require(success, "preHook failed");
            }
        }
    }

    function postHook(address target, uint256 value, bytes memory data) internal {
        mapping(address => address) storage _plugins = pluginsMapping();
        address[] memory plugins = _plugins.list(AddressLinkedList.SENTINEL_ADDRESS, _plugins.size());
        for (uint256 i = 0; i < plugins.length; i++) {
            if (IPlugin(plugins[i]).isHookCall(IPlugin.HookType.PostHook)) {
                //TODO is getHookCallType necessary? call or d`elegatecall?
                (bool success,) = CallHelper.call(
                    IPlugin(plugins[i]).getHookCallType(IPlugin.HookType.PostHook),
                    plugins[i],
                    abi.encodeCall(IPlugin.postHook, (target, value, data))
                );
                require(success, "postHook failed");
            }
        }
    }

    function execDelegateCall(IPlugin target, bytes memory data) external {
        _requireFromEntryPointOrOwner();
        require(_isAuthorizedPlugin(address(target)));

        //#TODO

        CallHelper.callWithoutReturnData(CallHelper.CallType.DelegateCall, address(target), data);
    }
}
