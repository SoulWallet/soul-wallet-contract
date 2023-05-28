// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../libraries/AccountStorage.sol";
import "../authority/Authority.sol";
import "../interfaces/IModuleManager.sol";
import "./PluginManager.sol";
import "../libraries/AddressLinkedList.sol";
import "../libraries/SelectorLinkedList.sol";
import "./InternalExecutionManager.sol";

abstract contract ModuleManager is IModuleManager, PluginManager, InternalExecutionManager {
    using AddressLinkedList for mapping(address => address);
    using SelectorLinkedList for mapping(bytes4 => bytes4);

    bytes4 internal constant FUNC_ADD_MODULE = bytes4(keccak256("addModule(address,bytes)"));
    bytes4 internal constant FUNC_REMOVE_MODULE = bytes4(keccak256("removeModule(address)"));

    function modulesMapping() private view returns (mapping(address => address) storage modules) {
        modules = AccountStorage.layout().modules;
    }

    function moduleSelectorsMapping()
        private
        view
        returns (mapping(address => mapping(bytes4 => bytes4)) storage moduleSelectors)
    {
        moduleSelectors = AccountStorage.layout().moduleSelectors;
    }

    function _isAuthorizedModule(address module) private view returns (bool) {
        return modulesMapping().isExist(module);
    }

    function isAuthorizedSelector(address module, bytes4 selector) private view returns (bool) {
        if (!modulesMapping().isExist(module)) {
            return false;
        }
        mapping(address => mapping(bytes4 => bytes4)) storage moduleSelectors = moduleSelectorsMapping();
        return moduleSelectors[module].isExist(selector);
    }

    function isAuthorizedModule(address module) external override returns (bool) {
        return _isAuthorizedModule(module);
    }

    function addModule(bytes calldata moduleAndData) internal {
        require(moduleAndData.length >= 20, "module address empty");
        address moduleAddress = address(bytes20(moduleAndData[:20]));
        bytes memory initData = moduleAndData[20:];
        addModule(moduleAddress, initData);
    }

    function addModule(address moduleAddress, bytes memory initData) internal {
        IModule aModule = IModule(moduleAddress);
        require(aModule.supportsInterface(type(IModule).interfaceId), "unknown module");
        bytes4[] memory requiredFunctions = aModule.requiredFunctions();
        require(requiredFunctions.length > 0, "selectors empty");
        mapping(address => address) storage modules = modulesMapping();
        modules.add(moduleAddress);
        mapping(address => mapping(bytes4 => bytes4)) storage moduleSelectors = moduleSelectorsMapping();
        moduleSelectors[moduleAddress].add(requiredFunctions);
        aModule.walletInit(initData);
        emit ModuleAdded(moduleAddress);
    }

    function removeModule(address module) internal {
        mapping(address => address) storage modules = modulesMapping();
        modules.remove(module);

        mapping(address => mapping(bytes4 => bytes4)) storage moduleSelectors = moduleSelectorsMapping();
        moduleSelectors[module].clear();

        try IModule(module).walletDeInit() {
            emit ModuleRemoved(module);
        } catch {
            emit ModuleRemovedWithError(module);
        }
    }

    function listModule() external view override returns (address[] memory modules, bytes4[][] memory selectors) {
        mapping(address => address) storage _modules = modulesMapping();
        uint256 moduleSize = modulesMapping().size();
        modules = new address[](moduleSize);
        mapping(address => mapping(bytes4 => bytes4)) storage moduleSelectors = moduleSelectorsMapping();
        selectors = new bytes4[][](moduleSize);

        uint256 i = 0;
        address addr = _modules[AddressLinkedList.SENTINEL_ADDRESS];
        while (uint160(addr) > AddressLinkedList.SENTINEL_UINT) {
            {
                modules[i] = addr;
                mapping(bytes4 => bytes4) storage moduleSelector = moduleSelectors[addr];

                {
                    uint256 selectorSize = moduleSelector.size();
                    bytes4[] memory _selectors = new bytes4[](selectorSize);
                    uint256 j = 0;
                    bytes4 selector = moduleSelector[SelectorLinkedList.SENTINEL_SELECTOR];
                    while (uint32(selector) > SelectorLinkedList.SENTINEL_UINT) {
                        _selectors[j] = selector;

                        selector = moduleSelector[selector];
                        unchecked {
                            j++;
                        }
                    }
                    selectors[i] = _selectors;
                }
            }

            addr = _modules[addr];
            unchecked {
                i++;
            }
        }
    }

    function execFromModule(bytes calldata data) external override {
        bytes4 selector = bytes4(data[0:4]);
        require(isAuthorizedSelector(msg.sender, selector), "unauthorized module selector");

        if (selector == FUNC_ADD_MODULE) {
            // addModule(address,bytes)
            (address moduleAddress, bytes memory initData) = abi.decode(data[4:], (address, bytes));
            addModule(moduleAddress, initData);
        } else if (selector == FUNC_REMOVE_MODULE) {
            // removeModule(address)
            address module = abi.decode(data[4:], (address));
            removeModule(module);
        } else if (selector == FUNC_ADD_PLUGIN) {
            // addPlugin((address,bytes))
            (address pluginAddress, bytes memory initData) = abi.decode(data[4:], (address, bytes));
            addPlugin(pluginAddress, initData);
        } else if (selector == FUNC_REMOVE_PLUGIN) {
            // removePlugin(address)
            address plugin = abi.decode(data[4:], (address));
            removePlugin(plugin);
        } else if (selector == FUNC_EXECUTE) {
            // execute(address,uint256,bytes)
            (address to, uint256 value, bytes memory _data) = abi.decode(data[4:], (address, uint256, bytes));
            _execute(to, value, _data);
        } else if (selector == FUNC_EXECUTE_BATCH) {
            // executeBatch(address[],bytes[])
            (address[] memory tos, bytes[] memory _datas) = abi.decode(data[4:], (address[], bytes[]));
            _executeBatch(tos, _datas);
        } else if (selector == FUNC_EXECUTE_BATCH_VALUE) {
            // executeBatch(address[],uint256[],bytes[])
            (address[] memory tos, uint256[] memory values, bytes[] memory _datas) =
                abi.decode(data[4:], (address[], uint256[], bytes[]));
            _executeBatch(tos, values, _datas);
        } else {
            CallHelper.call(address(this), data);
        }
    }
}
