// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../libraries/AccountStorage.sol";
import "../authority/Authority.sol";
import "../interfaces/IModuleManager.sol";
import "./PluginManager.sol";

abstract contract ModuleManager is IModuleManager, PluginManager {
    address public immutable defaultModuleManager;

    bytes4 private constant SENTINEL_SELECTOR = 0x00000001;
    address private constant SENTINEL_MODULE = address(1);

    bytes4 internal constant FUNC_ADD_MODULE =
        bytes4(keccak256("addModule(address,bytes4[],bytes)"));
    bytes4 internal constant FUNC_REMOVE_MODULE =
        bytes4(keccak256("removeModule(address)"));

    constructor(address _defaultModuleManager) {
        defaultModuleManager = _defaultModuleManager;
    }

    function isAuthorizedModule(
        address module,
        bytes4 selector
    ) internal view returns (bool) {
        if (
            defaultModuleManager == module &&
            (selector == FUNC_ADD_MODULE || selector == FUNC_REMOVE_MODULE)
        ) {
            return true;
        }

        // TODO

        revert("not implemented");
    }

    function isAuthorizedModule(
        address module
    ) external override returns (bool) {
        (module);
        return false;
    }

    function addModule(Module calldata aModule) internal {
        require(aModule.selectors.length > 0, "selectors empty");
        address module = address(aModule.module);
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

        bytes4 firstSelector = aModule.selectors[0];
        require(firstSelector > SENTINEL_SELECTOR, "selector error");
        moduleSelectors[SENTINEL_SELECTOR] = firstSelector;
        bytes4 _selector = firstSelector;

        for (uint i = 1; i < aModule.selectors.length; i++) {
            bytes4 current = aModule.selectors[i];
            require(current > _selector, "selectors not sorted");

            moduleSelectors[_selector] = current;

            _selector = current;
        }

        moduleSelectors[_selector] = SENTINEL_SELECTOR;

        emit ModuleAdded(module, aModule.selectors);
    }

    function removeModule(address module) internal {
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

    function execFromModule(bytes calldata data) external override {
        // get 4bytes
        bytes4 selector = bytes4(data[0:4]);
        require(
            isAuthorizedModule(msg.sender, selector),
            "unauthorized module"
        );

        if (selector == FUNC_ADD_MODULE) {
            //addModule( );
        } else if (selector == FUNC_REMOVE_MODULE) {
            //removeModule( );
        } else if (selector == FUNC_ADD_PLUGIN) {
            //addPlugin()
        } else if (selector == FUNC_REMOVE_PLUGIN) {
            //removePlugin();
        } else {
            // TODO
        }

        (data);
        revert("not implemented");
    }
}
