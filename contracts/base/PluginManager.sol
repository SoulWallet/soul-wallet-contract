// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../interfaces/IPluginManager.sol";
import "../interfaces/IPlugin.sol";
import "../libraries/AccountStorage.sol";
import "../authority/Authority.sol";
import "../libraries/AddressLinkedList.sol";
import "../interfaces/IPluggable.sol";
import "../interfaces/IPluginStorage.sol";

abstract contract PluginManager is IPluginManager, Authority, IPluginStorage {
    uint8 private constant _GUARD_HOOK = 1 << 0;
    uint8 private constant _PRE_HOOK = 1 << 1;
    uint8 private constant _POST_HOOK = 1 << 2;

    using AddressLinkedList for mapping(address => address);

    function addPlugin(bytes calldata pluginAndData) external override onlyModule {
        _addPlugin(pluginAndData);
    }

    function _addPlugin(bytes calldata pluginAndData) internal {
        if (pluginAndData.length < 20) {
            revert Errors.PLUGIN_ADDRESS_EMPTY();
        }
        address pluginAddress = address(bytes20(pluginAndData[:20]));
        bytes calldata initData = pluginAndData[20:];
        IPlugin aPlugin = IPlugin(pluginAddress);
        if (!aPlugin.supportsInterface(type(IPlugin).interfaceId)) {
            revert Errors.PLUGIN_NOT_SUPPORT_INTERFACE();
        }
        AccountStorage.Layout storage l = AccountStorage.layout();
        uint8 hookType = aPlugin.supportsHook();

        if (hookType & 7 /*  _GUARD_HOOK | _PRE_HOOK | _POST_HOOK */ == 0) {
            revert Errors.PLUGIN_HOOK_TYPE_ERROR();
        }

        if (hookType & _GUARD_HOOK == _GUARD_HOOK) {
            l.guardHookPlugins.add(pluginAddress);
        }
        if (hookType & _PRE_HOOK == _PRE_HOOK) {
            l.preHookPlugins.add(pluginAddress);
        }
        if (hookType & _POST_HOOK == _POST_HOOK) {
            l.postHookPlugins.add(pluginAddress);
        }
        l.plugins.add(pluginAddress);
        if (!call(pluginAddress, abi.encodeWithSelector(IPluggable.walletInit.selector, initData))) {
            revert Errors.PLUGIN_INIT_FAILED();
        }
        emit PluginAdded(pluginAddress);
    }

    function removePlugin(address plugin) external override onlyModule {
        AccountStorage.Layout storage l = AccountStorage.layout();
        l.plugins.remove(plugin);
        bool success = call(plugin, abi.encodeWithSelector(IPluggable.walletDeInit.selector));
        if (success) {
            emit PluginRemoved(plugin);
        } else {
            emit PluginRemovedWithError(plugin);
        }
        l.guardHookPlugins.tryRemove(plugin);
        l.preHookPlugins.tryRemove(plugin);
        l.postHookPlugins.tryRemove(plugin);
    }

    function isAuthorizedPlugin(address plugin) external view override returns (bool) {
        return AccountStorage.layout().plugins.isExist(plugin);
    }

    function listPlugin(uint8 hookType) external view override returns (address[] memory plugins) {
        if (hookType == 0) {
            mapping(address => address) storage _plugins = AccountStorage.layout().plugins;
            plugins = _plugins.list(AddressLinkedList.SENTINEL_ADDRESS, _plugins.size());
        } else if (hookType == _GUARD_HOOK) {
            mapping(address => address) storage _plugins = AccountStorage.layout().guardHookPlugins;
            plugins = _plugins.list(AddressLinkedList.SENTINEL_ADDRESS, _plugins.size());
        } else if (hookType == _PRE_HOOK) {
            mapping(address => address) storage _plugins = AccountStorage.layout().preHookPlugins;
            plugins = _plugins.list(AddressLinkedList.SENTINEL_ADDRESS, _plugins.size());
        } else if (hookType == _POST_HOOK) {
            mapping(address => address) storage _plugins = AccountStorage.layout().postHookPlugins;
            plugins = _plugins.list(AddressLinkedList.SENTINEL_ADDRESS, _plugins.size());
        } else {
            revert Errors.PLUGIN_HOOK_TYPE_ERROR();
        }
    }

    function _nextGuardHookData(bytes calldata guardHookData, uint256 cursor)
        private
        pure
        returns (address _guardAddr, uint256 _cursorFrom, uint256 _cursorEnd)
    {
        uint256 dataLen = guardHookData.length;
        uint48 guardSigLen;
        if (dataLen > cursor) {
            unchecked {
                _cursorEnd = cursor + 20;
            }
            bytes calldata _guardAddrBytes = guardHookData[cursor:_cursorEnd];
            assembly ("memory-safe") {
                _guardAddr := shr(0x60, calldataload(_guardAddrBytes.offset))
            }
            require(_guardAddr != address(0));
            unchecked {
                cursor = _cursorEnd;
                _cursorEnd = cursor + 6;
            }
            bytes calldata _guardSigLen = guardHookData[cursor:_cursorEnd];
            assembly ("memory-safe") {
                guardSigLen := shr(0xd0, calldataload(_guardSigLen.offset))
            }
            unchecked {
                cursor = _cursorEnd;
                _cursorEnd = cursor + guardSigLen;
            }
            _cursorFrom = cursor;
        }
    }

    function guardHook(UserOperation calldata userOp, bytes32 userOpHash, bytes calldata guardHookData)
        internal
        returns (bool)
    {
        AccountStorage.Layout storage l = AccountStorage.layout();
        mapping(address => address) storage _plugins = l.guardHookPlugins;

        /* 
            +--------------------------------------------------------------------------------+  
            |                            multi-guardHookInputData                            |  
            +--------------------------------------------------------------------------------+  
            |   guardHookInputData  |  guardHookInputData   |   ...  |  guardHookInputData   |
            +-----------------------+--------------------------------------------------------+  
            |     dynamic data      |     dynamic data      |   ...  |     dynamic data      |
            +--------------------------------------------------------------------------------+

            +----------------------------------------------------------------------+  
            |                                guardHookInputData                    |  
            +----------------------------------------------------------------------+  
            |   guardHook address  |   input data length   |      input data       |
            +----------------------+-----------------------------------------------+  
            |        20bytes       |     6bytes(uint48)    |         bytes         |
            +----------------------------------------------------------------------+
         */
        address _guardAddr;
        uint256 _cursorFrom;
        uint256 _cursorEnd;
        (_guardAddr, _cursorFrom, _cursorEnd) = _nextGuardHookData(guardHookData, _cursorEnd);

        address addr = _plugins[AddressLinkedList.SENTINEL_ADDRESS];
        while (uint160(addr) > AddressLinkedList.SENTINEL_UINT) {
            {
                bytes calldata currentGuardHookData;
                address plugin = addr;
                if (plugin == _guardAddr) {
                    currentGuardHookData = guardHookData[_cursorFrom:_cursorEnd];
                    // next
                    _guardAddr = address(0);
                    if (_cursorEnd > 0) {
                        (_guardAddr, _cursorFrom, _cursorEnd) = _nextGuardHookData(guardHookData, _cursorEnd);
                    }
                } else {
                    currentGuardHookData = guardHookData[0:0];
                }
                bool success =
                    call(plugin, abi.encodeCall(IPlugin.guardHook, (userOp, userOpHash, currentGuardHookData)));
                if (!success) {
                    return false;
                }
            }
            addr = _plugins[addr];
        }
        if (_guardAddr != address(0)) {
            revert Errors.INVALID_GUARD_HOOK_DATA();
        }
        return true;
    }

    modifier executeHook(address target, uint256 value, bytes memory data) {
        AccountStorage.Layout storage l = AccountStorage.layout();
        {
            mapping(address => address) storage _preHookPlugins = l.preHookPlugins;
            address addr = _preHookPlugins[AddressLinkedList.SENTINEL_ADDRESS];
            while (uint160(addr) > AddressLinkedList.SENTINEL_UINT) {
                {
                    address plugin = addr;
                    if (!call(plugin, abi.encodeCall(IPlugin.preHook, (target, value, data)))) {
                        revert Errors.PLUGIN_PRE_HOOK_FAILED();
                    }
                }
                addr = _preHookPlugins[addr];
            }
        }
        _;
        {
            mapping(address => address) storage _postHookPlugins = l.postHookPlugins;

            address addr = _postHookPlugins[AddressLinkedList.SENTINEL_ADDRESS];
            while (uint160(addr) > AddressLinkedList.SENTINEL_UINT) {
                {
                    address plugin = addr;
                    if (!call(plugin, abi.encodeCall(IPlugin.postHook, (target, value, data)))) {
                        revert Errors.PLUGIN_POST_HOOK_FAILED();
                    }
                }
                addr = _postHookPlugins[addr];
            }
        }
    }

    function call(address target, bytes memory data) private returns (bool success) {
        assembly ("memory-safe") {
            success := call(gas(), target, 0, add(data, 0x20), mload(data), 0, 0)
        }
    }

    modifier onlyPlugin() {
        if (AccountStorage.layout().plugins[msg.sender] == address(0)) {
            revert Errors.PLUGIN_NOT_REGISTERED();
        }
        _;
    }

    function pluginDataStore(bytes32 key, bytes calldata value) external override onlyPlugin {
        AccountStorage.layout().pluginDataBytes[msg.sender][key] = value;
    }

    function pluginDataLoad(address plugin, bytes32 key) external view override returns (bytes memory) {
        return AccountStorage.layout().pluginDataBytes[plugin][key];
    }
}
