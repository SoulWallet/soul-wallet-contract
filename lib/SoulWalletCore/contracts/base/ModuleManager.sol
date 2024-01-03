// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IModule} from "../interface/IModule.sol";
import {IPluggable} from "../interface/IPluggable.sol";
import {IModuleManager} from "../interface/IModuleManager.sol";
import {AccountStorage} from "../utils/AccountStorage.sol";
import {Authority} from "./Authority.sol";
import {AddressLinkedList} from "../utils/AddressLinkedList.sol";
import {SelectorLinkedList} from "../utils/SelectorLinkedList.sol";
import {ModuleManagerSnippet} from "../snippets/ModuleManager.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

abstract contract ModuleManager is IModuleManager, Authority, ModuleManagerSnippet {
    using AddressLinkedList for mapping(address => address);
    using SelectorLinkedList for mapping(bytes4 => bytes4);

    error MODULE_EXECUTE_FROM_MODULE_RECURSIVE();
    error INVALID_MODULE();
    error CALLER_MUST_BE_AUTHORIZED_MODULE();

    bytes4 private constant INTERFACE_ID_MODULE = type(IModule).interfaceId;

    function _moduleMapping() internal view returns (mapping(address => address) storage modules) {
        modules = AccountStorage.layout().modules;
    }

    /**
     * @dev checks whether the caller is a authorized module
     *  caller: msg.sender
     *  method: msg.sig
     * @return bool
     */
    function _isAuthorizedModule() internal view override returns (bool) {
        return AccountStorage.layout().moduleSelectors[msg.sender].isExist(msg.sig);
    }

    /**
     * @dev checks whether a address is a authorized module
     */
    function _isInstalledModule(address module) internal view virtual override returns (bool) {
        return _moduleMapping().isExist(module);
    }

    /**
     * @dev checks whether a address is a installed module
     */
    function isInstalledModule(address module) external view override returns (bool) {
        return _isInstalledModule(module);
    }

    /**
     * @dev checks whether a address is a module
     * note: If you need to extend the interface, override this function
     * @param moduleAddress module address
     */
    function _isSupportsModuleInterface(address moduleAddress)
        internal
        view
        virtual
        override
        returns (bool supported)
    {
        bytes memory callData = abi.encodeWithSelector(IERC165.supportsInterface.selector, INTERFACE_ID_MODULE);
        assembly ("memory-safe") {
            // memorySafe: The scratch space between memory offset 0 and 64.

            let result := staticcall(gas(), moduleAddress, add(callData, 0x20), mload(callData), 0x00, 0x20)
            if gt(result, 0) { supported := mload(0x00) }
        }
    }

    /**
     * @dev install a module
     * @param moduleAddress module address
     * @param initData module init data
     * @param selectors function selectors that the module is allowed to call
     */
    function _installModule(address moduleAddress, bytes memory initData, bytes4[] memory selectors)
        internal
        virtual
        override
    {
        if (_isSupportsModuleInterface(moduleAddress) == false) {
            revert INVALID_MODULE();
        }

        mapping(address => address) storage modules = _moduleMapping();
        modules.add(moduleAddress);
        mapping(bytes4 => bytes4) storage moduleSelectors = AccountStorage.layout().moduleSelectors[moduleAddress];

        for (uint256 i = 0; i < selectors.length; i++) {
            moduleSelectors.add(selectors[i]);
        }
        bytes memory callData = abi.encodeWithSelector(IPluggable.Init.selector, initData);
        bytes4 invalidModuleSelector = INVALID_MODULE.selector;
        assembly ("memory-safe") {
            // memorySafe: The scratch space between memory offset 0 and 64.

            let result := call(gas(), moduleAddress, 0, add(callData, 0x20), mload(callData), 0x00, 0x00)
            if iszero(result) {
                mstore(0x00, invalidModuleSelector)
                revert(0x00, 4)
            }
        }

        emit ModuleInstalled(moduleAddress);
    }

    /**
     * @dev uninstall a module
     * @param moduleAddress module address
     */
    function _uninstallModule(address moduleAddress) internal virtual override {
        mapping(address => address) storage modules = _moduleMapping();
        modules.remove(moduleAddress);
        AccountStorage.layout().moduleSelectors[moduleAddress].clear();
        (bool success,) =
            moduleAddress.call{gas: 1000000 /* max to 1M gas */ }(abi.encodeWithSelector(IPluggable.DeInit.selector));
        if (success) {
            emit ModuleUninstalled(moduleAddress);
        } else {
            emit ModuleUninstalledwithError(moduleAddress);
        }
    }

    /**
     * @dev uninstall a module
     * @param moduleAddress module address
     */
    function uninstallModule(address moduleAddress) external virtual override {
        pluginManagementAccess();
        _uninstallModule(moduleAddress);
    }

    /**
     * @dev Provides a list of all added modules and their respective authorized function selectors
     * @return modules An array of the addresses of all added modules
     * @return selectors A 2D array where each inner array represents the function selectors
     * that the corresponding module in the 'modules' array is allowed to call
     */
    function listModule()
        external
        view
        virtual
        override
        returns (address[] memory modules, bytes4[][] memory selectors)
    {
        mapping(address => address) storage _modules = _moduleMapping();
        uint256 moduleSize = _moduleMapping().size();
        modules = new address[](moduleSize);
        mapping(address => mapping(bytes4 => bytes4)) storage moduleSelectors = AccountStorage.layout().moduleSelectors;
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
     * @notice Allows a module to execute a function within the system. This ensures that the
     * module can only call functions it is permitted to.
     * @param dest The address of the destination contract where the function will be executed
     * @param value The amount of ether (in wei) to be sent with the function call
     * @param func The function data to be executed
     */
    function executeFromModule(address dest, uint256 value, bytes memory func) external virtual override {
        if (_isAuthorizedModule() == false) {
            revert CALLER_MUST_BE_AUTHORIZED_MODULE();
        }

        if (dest == address(this)) revert MODULE_EXECUTE_FROM_MODULE_RECURSIVE();
        assembly ("memory-safe") {
            // memorySafe: Memory allocated by yourself using a mechanism like the allocate function described above.

            function allocate(length) -> pos {
                pos := mload(0x40)
                mstore(0x40, add(pos, length))
            }

            let result := call(gas(), dest, value, add(func, 0x20), mload(func), 0, 0)

            let returndataPtr := allocate(returndatasize())
            returndatacopy(returndataPtr, 0, returndatasize())

            if iszero(result) { revert(returndataPtr, returndatasize()) }
            return(returndataPtr, returndatasize())
        }
    }
}
