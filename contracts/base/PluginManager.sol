// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../interfaces/IPluginManager.sol";
import "../interfaces/IPlugin.sol";
import "../libraries/AccountStorage.sol";
import "../authority/Authority.sol";
import "../libraries/AddressLinkedList.sol";
import "../interfaces/IPluggable.sol";

abstract contract PluginManager is IPluginManager, Authority {
    using AddressLinkedList for mapping(address => address);

    /**
     * @dev Make sure the plugin code does not contain the F4 (DELEGATECALL) opcode
     */
    function addPlugin(bytes calldata pluginAndData) external override onlyModule {
        _addPlugin(pluginAndData);
    }

    function _addPlugin(bytes calldata pluginAndData) internal {
        require(pluginAndData.length >= 20, "plugin address empty");
        address pluginAddress = address(bytes20(pluginAndData[:20]));
        bytes calldata initData = pluginAndData[20:];
        IPlugin aPlugin = IPlugin(pluginAddress);
        require(aPlugin.supportsInterface(type(IPlugin).interfaceId), "unknown plugin");
        AccountStorage.Layout storage l = AccountStorage.layout();
        (uint8 hookType, uint8 _callType) = aPlugin.supportsHook();
        require(_callType < 2, "unknow call type");
        uint256 callType = uint96(_callType);
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
        l.pluginCallTypes[pluginAddress] = callType;
        l.plugins.add(pluginAddress);
        require(
            call(callType, pluginAddress, abi.encodeWithSelector(IPluggable.walletInit.selector, initData)),
            "plugin init failed"
        );
        emit PluginAdded(pluginAddress);
    }

    function removePlugin(address plugin) external override onlyModule {
        AccountStorage.Layout storage l = AccountStorage.layout();
        l.plugins.remove(plugin);
        bool success = call(l.pluginCallTypes[plugin], plugin, abi.encodeWithSelector(IPluggable.walletDeInit.selector));
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

    function listPlugin() external view override returns (address[] memory plugins) {
        mapping(address => address) storage _plugins = AccountStorage.layout().plugins;
        plugins = _plugins.list(AddressLinkedList.SENTINEL_ADDRESS, _plugins.size());
    }

    function listGuardHookPlugin() external view override returns (address[] memory plugins) {
        mapping(address => address) storage _plugins = AccountStorage.layout().guardHookPlugins;
        plugins = _plugins.list(AddressLinkedList.SENTINEL_ADDRESS, _plugins.size());
    }

    function _nextGuardHookData(bytes calldata guardHookData, uint256 cursor)
        private
        pure
        returns (address _guardAddr, uint256 _cursorFrom, uint256 _cursorEnd)
    {
        uint256 dataLen = guardHookData.length;
        uint256 guardMinInputLen;
        uint48 guardSigLen;
        unchecked {
            guardMinInputLen = cursor + 26; /* 20+6 */
        }

        if (dataLen > guardMinInputLen) {
            unchecked {
                _cursorEnd = cursor + 20;
            }
            bytes calldata _guardAddrBytes = guardHookData[cursor:_cursorEnd];
            assembly {
                _guardAddr := shr(0x60, calldataload(_guardAddrBytes.offset))
            }
            unchecked {
                cursor = _cursorEnd;
                _cursorEnd = cursor + 6;
            }
            bytes calldata _guardSigLen = guardHookData[cursor:_cursorEnd];
            assembly {
                guardSigLen := shr(0xd0, calldataload(_guardSigLen.offset))
            }
            unchecked {
                cursor = _cursorEnd;
                _cursorEnd = cursor + guardSigLen;
            }
            _cursorFrom = cursor;
        } else {
            _guardAddr = address(0);
            _cursorFrom = 0;
            _cursorEnd = 0;
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
                bool success = call(
                    l.pluginCallTypes[plugin],
                    plugin,
                    abi.encodeCall(IPlugin.guardHook, (userOp, userOpHash, currentGuardHookData))
                );
                if (!success) {
                    return false;
                }
            }
            addr = _plugins[addr];
        }
        if (_guardAddr != address(0)) {
            revert("invalid guardHookData");
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
                    require(
                        call(l.pluginCallTypes[plugin], plugin, abi.encodeCall(IPlugin.preHook, (target, value, data))),
                        "preHook failed"
                    );
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
                    require(
                        call(l.pluginCallTypes[plugin], plugin, abi.encodeCall(IPlugin.postHook, (target, value, data))),
                        "postHook failed"
                    );
                }
                addr = _postHookPlugins[addr];
            }
        }
    }

    function execDelegateCall(address target, bytes memory data) external onlyExecutionManagerOrSimulate {
        require(AccountStorage.layout().pluginCallTypes[target] == 1, "not delegatecall plugin");
        assembly {
            let succ := delegatecall(gas(), target, add(data, 0x20), mload(data), 0, 0)
            returndatacopy(0, 0, returndatasize())
            if eq(succ, 0) { revert(0, returndatasize()) }
            return(0, returndatasize())
        }
    }

    function call(uint256 callType, address target, bytes memory data) private returns (bool success) {
        assembly {
            switch callType
            case 0 { success := call(gas(), target, 0, add(data, 0x20), mload(data), 0, 0) }
            default { success := delegatecall(gas(), target, add(data, 0x20), mload(data), 0, 0) }
        }
    }
}
