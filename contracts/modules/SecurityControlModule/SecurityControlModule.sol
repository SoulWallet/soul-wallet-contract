// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./BaseSecurityControlModule.sol";
import "../../trustedContractManager/ITrustedContractManager.sol";

contract SecurityControlModule is BaseSecurityControlModule {
    error UnsupportedSelectorError(bytes4 selector);
    error RemoveSelfError();

    ITrustedContractManager public immutable trustedModuleManager;
    ITrustedContractManager public immutable trustedPluginManager;

    bytes4 private constant FUNC_ADD_MODULE = bytes4(keccak256("addModule(address,bytes)"));
    bytes4 private constant FUNC_ADD_PLUGIN = bytes4(keccak256("addPlugin(address,bytes)"));
    bytes4 private constant FUNC_REMOVE_MODULE = bytes4(keccak256("removeModule(address)"));
    bytes4 private constant FUNC_REMOVE_PLUGIN = bytes4(keccak256("removePlugin(address)"));

    constructor(ITrustedContractManager _trustedModuleManager, ITrustedContractManager _trustedPluginManager) {
        trustedModuleManager = _trustedModuleManager;
        trustedPluginManager = _trustedPluginManager;
    }

    function preExecute(address _target, bytes calldata _data, bytes32 _txId) internal override {
        bytes4 _func = bytes4(_data[0:4]);
        if (_func == FUNC_ADD_MODULE) {
            address _module;
            (_module,) = abi.decode(_data[4:], (address, bytes));
            if (!trustedModuleManager.isTrustedContract(_module)) {
                super.preExecute(_target, _data, _txId);
            }
        } else if (_func == FUNC_ADD_PLUGIN) {
            address _plugin;
            (_plugin,) = abi.decode(_data[4:], (address, bytes));
            if (!trustedPluginManager.isTrustedContract(_plugin)) {
                super.preExecute(_target, _data, _txId);
            }
        } else if (_func == FUNC_REMOVE_MODULE) {
            (address _module) = abi.decode(_data[4:], (address));
            if (_module == address(this)) {
                revert RemoveSelfError();
            }
            super.preExecute(_target, _data, _txId);
        } else if (_func == FUNC_REMOVE_PLUGIN) {
            super.preExecute(_target, _data, _txId);
        } else {
            revert UnsupportedSelectorError(_func);
        }
    }

    function requiredFunctions() external pure override returns (bytes4[] memory) {
        bytes4[] memory _funcs = new bytes4[](4);
        _funcs[0] = FUNC_ADD_MODULE;
        _funcs[1] = FUNC_ADD_PLUGIN;
        _funcs[2] = FUNC_REMOVE_MODULE;
        _funcs[3] = FUNC_REMOVE_PLUGIN;
        return _funcs;
    }
}
