// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "./BaseSecurityControlModule.sol";
import "./trustedContractManager/ITrustedContractManager.sol";
import {ISoulWalletHookManager} from "../../interfaces/ISoulWalletHookManager.sol";
import {ISoulWalletModuleManager} from "../../interfaces/ISoulWalletModuleManager.sol";
import {ISoulWalletValidatorManager} from "../../interfaces/ISoulWalletValidatorManager.sol";
import {IHookManager} from "@soulwallet-core/contracts/interface/IHookManager.sol";
import {IModuleManager} from "@soulwallet-core/contracts/interface/IModuleManager.sol";
import {IValidatorManager} from "@soulwallet-core/contracts/interface/IValidatorManager.sol";

contract SecurityControlModule is BaseSecurityControlModule {
    error UnsupportedSelectorError(bytes4 selector);
    error RemoveSelfError();

    ITrustedContractManager public immutable trustedModuleManager;
    ITrustedContractManager public immutable trustedHookManager;
    ITrustedContractManager public immutable trustedValidatorManager;

    constructor(
        ITrustedContractManager _trustedModuleManager,
        ITrustedContractManager _trustedHookManager,
        ITrustedContractManager _trustedValidatorManager
    ) {
        trustedModuleManager = _trustedModuleManager;
        trustedHookManager = _trustedHookManager;
        trustedValidatorManager = _trustedValidatorManager;
    }

    function _preExecute(address _target, bytes calldata _data, bytes32 _txId) internal override {
        bytes4 _func = bytes4(_data[0:4]);
        if (_func == ISoulWalletModuleManager.installModule.selector) {
            address _module = address(bytes20(_data[68:88])); // 4 sig + 32 bytes + 32 bytes
            if (!trustedModuleManager.isTrustedContract(_module)) {
                super._preExecute(_target, _data, _txId);
            }
        } else if (_func == ISoulWalletHookManager.installHook.selector) {
            address _hook = address(bytes20(_data[68:88])); // 4 sig + 32 bytes + 32 bytes
            if (!trustedHookManager.isTrustedContract(_hook)) {
                super._preExecute(_target, _data, _txId);
            }
        } else if (_func == ISoulWalletValidatorManager.installValidator.selector) {
            address _validator = address(bytes20(_data[68:88])); // 4 sig + 32 bytes + 32 bytes
            if (!trustedValidatorManager.isTrustedContract(_validator)) {
                super._preExecute(_target, _data, _txId);
            }
        } else if (_func == IModuleManager.uninstallModule.selector) {
            (address _module) = abi.decode(_data[4:], (address));
            if (_module == address(this)) {
                revert RemoveSelfError();
            }
            super._preExecute(_target, _data, _txId);
        } else if (_func == IHookManager.uninstallHook.selector) {
            super._preExecute(_target, _data, _txId);
        } else if (_func == IValidatorManager.uninstallValidator.selector) {
            super._preExecute(_target, _data, _txId);
        } else {
            revert UnsupportedSelectorError(_func);
        }
    }

    function requiredFunctions() external pure override returns (bytes4[] memory) {
        bytes4[] memory _funcs = new bytes4[](6);
        _funcs[0] = ISoulWalletModuleManager.installModule.selector;
        _funcs[1] = IModuleManager.uninstallModule.selector;
        _funcs[2] = ISoulWalletHookManager.installHook.selector;
        _funcs[3] = IHookManager.uninstallHook.selector;
        _funcs[4] = ISoulWalletValidatorManager.installValidator.selector;
        _funcs[5] = IValidatorManager.uninstallValidator.selector;
        return _funcs;
    }
}
