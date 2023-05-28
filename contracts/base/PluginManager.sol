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

    function addPlugin(bytes calldata pluginAndData) internal {
        require(pluginAndData.length >= 20, "plugin address empty");
        address moduleAddress = address(bytes20(pluginAndData[:20]));
        bytes memory initData = pluginAndData[20:];
        addPlugin(moduleAddress, initData);
    }

    function addPlugin(address pluginAddress, bytes memory initData) internal {
        IPlugin aPlugin = IPlugin(pluginAddress);
        require(aPlugin.supportsInterface(type(IPlugin).interfaceId), "unknown plugin");
        AccountStorage.Layout storage l = AccountStorage.layout();
        (uint8 hookType, CallHelper.CallType callType) = aPlugin.supportsHook();
        require(callType != CallHelper.CallType.Unknown, "unknow call type");
        l.pluginCallType[pluginAddress] = callType;
        /*
            uint8 internal constant GUARD_HOOK = 0x1;
            uint8 internal constant PRE_HOOK = 0x2;
            uint8 internal constant POST_HOOK = 0x4;
         */
        if (hookType & 0x1 == 0x1) {
            l.guardHookPlugins.add(pluginAddress);
        }
        if (hookType & 0x2 == 0x2) {
            l.preHookPlugins.add(pluginAddress);
        }
        if (hookType & 0x4 == 0x4) {
            l.postHookPlugins.add(pluginAddress);
        }
        l.plugins.add(pluginAddress);

        aPlugin.walletInit(initData);

        emit PluginAdded(pluginAddress);
    }

    function removePlugin(address plugin) internal {
        AccountStorage.Layout storage l = AccountStorage.layout();
        l.plugins.remove(plugin);
        l.guardHookPlugins.tryRemove(plugin);
        l.preHookPlugins.tryRemove(plugin);
        l.postHookPlugins.tryRemove(plugin);
        l.pluginCallType[plugin] = CallHelper.CallType.Unknown;

        try IPlugin(plugin).walletDeInit() {
            emit PluginRemoved(plugin);
        } catch {
            emit PluginRemovedWithError(plugin);
        }
    }

    function isAuthorizedPlugin(address plugin) external view override returns (bool) {
        return AccountStorage.layout().plugins.isExist(plugin);
    }

    function listPlugin() external view override returns (address[] memory plugins) {
        mapping(address => address) storage _plugins = AccountStorage.layout().plugins;
        plugins = _plugins.list(AddressLinkedList.SENTINEL_ADDRESS, _plugins.size());
    }

    function guardHook(UserOperation calldata userOp, bytes32 userOpHash) internal returns (bool) {
        AccountStorage.Layout storage l = AccountStorage.layout();
        mapping(address => address) storage _plugins = l.guardHookPlugins;

        address addr = _plugins[AddressLinkedList.SENTINEL_ADDRESS];
        while (uint160(addr) > AddressLinkedList.SENTINEL_UINT) {
            {
                address plugin = addr;
                (bool success,) = CallHelper.call(
                    l.pluginCallType[plugin], plugin, abi.encodeCall(IPlugin.guardHook, (userOp, userOpHash))
                );
                if (!success) {
                    return false;
                }
            }
            addr = _plugins[addr];
        }

        return true;
    }

    function preHook(address target, uint256 value, bytes memory data) internal {
        AccountStorage.Layout storage l = AccountStorage.layout();
        mapping(address => address) storage _plugins = l.preHookPlugins;

        address addr = _plugins[AddressLinkedList.SENTINEL_ADDRESS];
        while (uint160(addr) > AddressLinkedList.SENTINEL_UINT) {
            {
                address plugin = addr;
                (bool success,) = CallHelper.call(
                    l.pluginCallType[plugin], plugin, abi.encodeCall(IPlugin.preHook, (target, value, data))
                );
                require(success, "preHook failed");
            }
            addr = _plugins[addr];
        }
    }

    function postHook(address target, uint256 value, bytes memory data) internal {
        AccountStorage.Layout storage l = AccountStorage.layout();
        mapping(address => address) storage _plugins = l.postHookPlugins;

        address addr = _plugins[AddressLinkedList.SENTINEL_ADDRESS];
        while (uint160(addr) > AddressLinkedList.SENTINEL_UINT) {
            {
                address plugin = addr;
                (bool success,) = CallHelper.call(
                    l.pluginCallType[plugin], plugin, abi.encodeCall(IPlugin.postHook, (target, value, data))
                );
                require(success, "postHook failed");
            }
            addr = _plugins[addr];
        }
    }

    function execDelegateCall(address target, bytes memory data) external onlyEntryPointOrOwner {
        require(
            AccountStorage.layout().pluginCallType[target] == CallHelper.CallType.DelegateCall,
            "not delegatecall plugin"
        );
        (bool success, bytes memory returnData) = CallHelper.delegatecall(target, data);
        assembly {
            switch success
            case 0 { revert(add(returnData, 0x20), mload(returnData)) }
            default { return(add(returnData, 0x20), mload(returnData)) }
        }
    }
}
