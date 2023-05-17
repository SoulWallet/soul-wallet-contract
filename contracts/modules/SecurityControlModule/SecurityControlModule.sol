// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;
import "./BaseSecurityControlModule.sol";
import "../../trustedContractManager/ITrustedContractManager.sol";

contract SecurityControlModule is BaseSecurityControlModule {
    error UnsupportedSelectorError(bytes4 selector);

    ITrustedContractManager public immutable trustedModuleManager;
    ITrustedContractManager public immutable trustedPluginManager;

    bytes4 internal constant FUNC_ADD_MODULE = bytes4(keccak256("addModule(address,bytes4[],bytes)"));
    bytes4 internal constant FUNC_ADD_PLUGIN = bytes4(keccak256("addPlugin(address,bytes)"));

    constructor(
        ITrustedContractManager _trustedModuleManager,
        ITrustedContractManager _trustedPluginManager
    ) {
        trustedModuleManager = _trustedModuleManager;
        trustedPluginManager = _trustedPluginManager;
    }

    function preExecute(address _target, bytes calldata _data, bytes32 _txId ) internal override {
        bytes4 _func = bytes4(_data[0:4]);
        if (_func == FUNC_ADD_MODULE) {
            address _module;
            (_module, , ) = abi.decode(_data[4:], (address, bytes4[], bytes));
            if (!trustedModuleManager.isTrustedContract(_module)) {
                super.preExecute(_target, _data, _txId);
            }
        } else if (_func == FUNC_ADD_PLUGIN) {
            address _plugin;
            (_plugin, ) = abi.decode(_data[4:], (address, bytes));
            if (!trustedPluginManager.isTrustedContract(_plugin)) {
                super.preExecute(_target, _data, _txId);
            }
        } else {
            super.preExecute(_target, _data, _txId);
        }
    }
}
