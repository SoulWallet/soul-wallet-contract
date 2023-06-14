// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../libraries/AccountStorage.sol";
import "../authority/Authority.sol";
import "../interfaces/IModuleManager.sol";
import "../interfaces/IPluginManager.sol";
import "../libraries/AddressLinkedList.sol";
import "../libraries/SelectorLinkedList.sol";

abstract contract ModuleManager is IModuleManager, Authority {
    using AddressLinkedList for mapping(address => address);
    using SelectorLinkedList for mapping(bytes4 => bytes4);

    function _modulesMapping() private view returns (mapping(address => address) storage modules) {
        modules = AccountStorage.layout().modules;
    }

    function _moduleSelectorsMapping()
        private
        view
        returns (mapping(address => mapping(bytes4 => bytes4)) storage moduleSelectors)
    {
        moduleSelectors = AccountStorage.layout().moduleSelectors;
    }

    function _isAuthorizedModule(address module) private view returns (bool) {
        return _modulesMapping().isExist(module);
    }

    function _isAuthorizedSelector(address module, bytes4 selector) private view returns (bool) {
        if (!_modulesMapping().isExist(module)) {
            return false;
        }
        mapping(address => mapping(bytes4 => bytes4)) storage moduleSelectors = _moduleSelectorsMapping();
        return moduleSelectors[module].isExist(selector);
    }

    function isAuthorizedModule(address module) external view override returns (bool) {
        return _isAuthorizedModule(module);
    }

    function addModule(bytes calldata moduleAndData) external override onlyModule {
        _addModule(moduleAndData);
    }

    function _addModule(bytes calldata moduleAndData) internal {
        if (moduleAndData.length < 20) {
            revert Errors.MODULE_ADDRESS_EMPTY();
        }
        address moduleAddress = address(bytes20(moduleAndData[:20]));
        bytes calldata initData = moduleAndData[20:];
        IModule aModule = IModule(moduleAddress);
        if (!aModule.supportsInterface(type(IModule).interfaceId)) {
            revert Errors.MODULE_NOT_SUPPORT_INTERFACE();
        }
        bytes4[] memory requiredFunctions = aModule.requiredFunctions();
        if (requiredFunctions.length == 0) {
            revert Errors.MODULE_SELECTORS_EMPTY();
        }
        mapping(address => address) storage modules = _modulesMapping();
        modules.add(moduleAddress);
        mapping(address => mapping(bytes4 => bytes4)) storage moduleSelectors = _moduleSelectorsMapping();
        moduleSelectors[moduleAddress].add(requiredFunctions);
        aModule.walletInit(initData);
        emit ModuleAdded(moduleAddress);
    }

    function removeModule(address module) external override onlyModule {
        mapping(address => address) storage modules = _modulesMapping();
        modules.remove(module);

        mapping(address => mapping(bytes4 => bytes4)) storage moduleSelectors = _moduleSelectorsMapping();
        moduleSelectors[module].clear();

        try IModule(module).walletDeInit() {
            emit ModuleRemoved(module);
        } catch {
            emit ModuleRemovedWithError(module);
        }
    }

    function listModule() external view override returns (address[] memory modules, bytes4[][] memory selectors) {
        mapping(address => address) storage _modules = _modulesMapping();
        uint256 moduleSize = _modulesMapping().size();
        modules = new address[](moduleSize);
        mapping(address => mapping(bytes4 => bytes4)) storage moduleSelectors = _moduleSelectorsMapping();
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

    function moduleEntryPoint(bytes calldata data) external override {
        bytes4 selector = bytes4(data[0:4]);
        if (!_isAuthorizedSelector(msg.sender, selector)) {
            revert Errors.MODULE_SELECTOR_UNAUTHORIZED();
        }
        (bool succ, bytes memory ret) = _moduleExec(data);
        assembly ("memory-safe") {
            if iszero(succ) { revert(add(ret, 0x20), mload(ret)) }
            return(add(ret, 0x20), mload(ret))
        }
    }

    function _moduleExec(bytes calldata data) private moduleHook returns (bool succ, bytes memory ret) {
        (succ, ret) = address(this).call{value: 0}(data);
    }

    function executeFromModule(address to, uint256 value, bytes memory data) external override onlyModule {
        assembly {
            /* not memory-safe */
            let result := call(gas(), to, value, add(data, 0x20), mload(data), 0, 0)
            if iszero(result) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }
}
