// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "../libraries/AccountStorage.sol";
import "../authority/Authority.sol";
import "../interfaces/IModuleManager.sol";
import "../interfaces/IPluginManager.sol";
import "../libraries/AddressLinkedList.sol";
import "../libraries/SelectorLinkedList.sol";

/**
 * @title ModuleManager
 * @notice Manages the modules that are added to, or removed from, the wallet
 * @dev Inherits functionalities from IModuleManager and Authority
 */
abstract contract ModuleManager is IModuleManager, Authority {
    using AddressLinkedList for mapping(address => address);
    using SelectorLinkedList for mapping(bytes4 => bytes4);

    /// @dev Returns the mapping of modules
    function _modulesMapping() private view returns (mapping(address => address) storage modules) {
        modules = AccountStorage.layout().modules;
    }

    /// @dev Returns the mapping of module selectors
    function _moduleSelectorsMapping()
        private
        view
        returns (mapping(address => mapping(bytes4 => bytes4)) storage moduleSelectors)
    {
        moduleSelectors = AccountStorage.layout().moduleSelectors;
    }
    /// @dev Checks if the sender is an authorized module

    function _isAuthorizedModule() internal view override returns (bool) {
        address module = msg.sender;
        if (!_modulesMapping().isExist(module)) {
            return false;
        }
        mapping(address => mapping(bytes4 => bytes4)) storage moduleSelectors = _moduleSelectorsMapping();
        return moduleSelectors[module].isExist(msg.sig);
    }
    /**
     * @notice Check if a module is authorized
     * @param module Address of the module
     * @return A boolean indicating the authorization status
     */

    function isAuthorizedModule(address module) external view override returns (bool) {
        return _modulesMapping().isExist(module);
    }

    /**
     * @notice Add a new module
     * @param moduleAndData Byte data containing the module address and initialization data
     */
    function addModule(bytes calldata moduleAndData) external override onlyModule {
        _addModule(moduleAndData);
    }
    /// @dev Internal function to add a module

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
    /**
     * @notice Remove a module
     * @param module Address of the module to be removed
     */

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
    /**
     * @notice List all the modules and their associated selectors
     * @return modules An array of module addresses
     * @return selectors A two-dimensional array of selectors
     */

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
    /**
     * @notice Execute a transaction from a module
     * @param to Address to which the transaction should be executed
     * @param value Amount of ETH (in wei) to be sent
     * @param data Transaction data
     */

    function executeFromModule(address to, uint256 value, bytes memory data) external override onlyModule {
        if (to == address(this)) revert Errors.MODULE_EXECUTE_FROM_MODULE_RECURSIVE();
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
