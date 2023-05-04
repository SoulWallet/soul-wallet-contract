// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../libraries/AccountStorage.sol";
import "./ImmediateEntryPoint.sol";
import "../interfaces/IModule.sol";

abstract contract ModuleManager is ImmediateEntryPoint {

    function requireFromAuthorizedModule(bytes4 selector) public view {
        if (address(_getEntryPoint()) == msg.sender) {
            return;
        }
        AccountStorage.Layout storage layout = AccountStorage.layout();
        require(layout.moduleMethodAllowed[msg.sender][selector], "methods not allowed");
    }

    function _authorizeModule(address module) external {
        AccountStorage.Layout storage layout = AccountStorage.layout();
        require(msg.sender == address(this));
        bytes4[] memory methods = IModule(module).allowedMethods();
        require(methods.length > 0);
        require(!layout.moduleAuthorized[module]);
        // TODO: require module is contract, require methods is in support list
        // TODO: require is in whitelist
        // TODO: add timelock
        layout.moduleAuthorized[module] = true;
        for (uint i = 0; i < methods.length; i++) {
            layout.moduleMethodAllowed[module][methods[i]] = true;
        }
        // TODO: IModule(module).init();
    }

    function _revokeModule(address module) external {
        AccountStorage.Layout storage layout = AccountStorage.layout();
        require(msg.sender == address(this));
        bytes4[] memory methods = IModule(module).allowedMethods();
        require(methods.length > 0);
        // TODO: add timelock

        for (uint i = 0; i < methods.length; i++) {
            delete layout.moduleMethodAllowed[module][methods[i]];
        }
        delete layout.moduleAuthorized[module];
        // TODO: IModule(module).deinit();
    }
}