// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../libraries/AccountStorage.sol";
import "../authority/Authority.sol";
import "../authority/ModuleAuth.sol";
import "../interfaces/IModuleManager.sol";
import "../authority/SafeModuleManagerAuth.sol";

abstract contract ModuleManager is
    IModuleManager,
    SafeModuleManagerAuth,
    ModuleAuth
{
    address public immutable safeModuleManager;

    bytes4 private constant SENTINEL_SELECTOR = 0x00000001;
    address private constant SENTINEL_MODULE = address(1);

    constructor(address aSafeModuleManager) {
        safeModuleManager = aSafeModuleManager;
    }

    function _moduleSelectorAuth(
        bytes4 selector
    ) internal view override returns (bool) {
        revert("not implemented");
    }

    function _safeModuleManager() internal view override returns (address) {
        return safeModuleManager;
    }

    function addModule(
        address module,
        bytes4[] calldata selectors
    ) external override _onlySafeModuleManager {
        require(selectors.length > 0, "selectors empty");
        AccountStorage.Layout storage layout = AccountStorage.layout();
        require(layout.modules[module] == address(0), "module already added");
        address _module = layout.modules[SENTINEL_MODULE];
        if (_module == address(0)) {
            _module = SENTINEL_MODULE;
        }
        layout.modules[SENTINEL_MODULE] = module;
        layout.modules[module] = _module;

        mapping(bytes4 => bytes4) storage moduleSelectors = layout
            .moduleSelectors[module];

        bytes4 firstSelector = selectors[0];
        require(firstSelector > SENTINEL_SELECTOR, "selector error");
        moduleSelectors[SENTINEL_SELECTOR] = firstSelector;
        bytes4 _selector = firstSelector;

        for (uint i = 1; i < selectors.length; i++) {
            bytes4 current = selectors[i];
            require(current > _selector, "selectors not sorted");

            moduleSelectors[_selector] = current;

            _selector = current;
        }

        moduleSelectors[_selector] = SENTINEL_SELECTOR;

        emit ModuleAdded(module, selectors);
    }

    function removeModule(
        address module
    ) external override _onlySafeModuleManager {
        AccountStorage.Layout storage layout = AccountStorage.layout();
        mapping(address => address) storage modules = layout.modules;
        require(modules[module] != address(0), "module not added");

        //#TODO

        emit ModuleRemoved(module);
    }

    function listModule()
        external
        view
        override
        returns (address[] memory modules, bytes4[][] memory selectors)
    {
        revert("not implemented");
    }
}
