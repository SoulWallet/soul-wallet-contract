// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./BaseSecurityControlModule.sol";
import "../../trustedContractManager/ITrustedContractManager.sol";
import "../../interfaces/IModuleManager.sol";
import "../../interfaces/IPluginManager.sol";

contract SecurityControlModule is BaseSecurityControlModule {
    error UnsupportedSelectorError(bytes4 selector);
    error RemoveSelfError();

    ITrustedContractManager public immutable trustedModuleManager;
    ITrustedContractManager public immutable trustedPluginManager;

    constructor(ITrustedContractManager _trustedModuleManager, ITrustedContractManager _trustedPluginManager) {
        trustedModuleManager = _trustedModuleManager;
        trustedPluginManager = _trustedPluginManager;
    }

    function _preExecute(address _target, bytes calldata _data, bytes32 _txId) internal override {
        bytes4 _func = bytes4(_data[0:4]);
        if (_func == IModuleManager.addModule.selector) {
            address _module = address(bytes20(_data[68:88])); // 4 sig + 32 bytes + 32 bytes
            if (!trustedModuleManager.isTrustedContract(_module)) {
                super._preExecute(_target, _data, _txId);
            }
        } else if (_func == IPluginManager.addPlugin.selector) {
            address _plugin = address(bytes20(_data[68:88])); // 4 sig + 32 bytes + 32 bytes
            if (!trustedPluginManager.isTrustedContract(_plugin)) {
                super._preExecute(_target, _data, _txId);
            }
        } else if (_func == IModuleManager.removeModule.selector) {
            (address _module) = abi.decode(_data[4:], (address));
            if (_module == address(this)) {
                revert RemoveSelfError();
            }
            super._preExecute(_target, _data, _txId);
        } else if (_func == IPluginManager.removePlugin.selector) {
            super._preExecute(_target, _data, _txId);
        } else {
            revert UnsupportedSelectorError(_func);
        }
    }

    function requiredFunctions() external pure override returns (bytes4[] memory) {
        bytes4[] memory _funcs = new bytes4[](4);
        _funcs[0] = IModuleManager.addModule.selector;
        _funcs[1] = IPluginManager.addPlugin.selector;
        _funcs[2] = IModuleManager.removeModule.selector;
        _funcs[3] = IPluginManager.removePlugin.selector;
        return _funcs;
    }
}
