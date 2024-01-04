// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SoulWalletCore} from "../contracts/SoulWalletCore.sol";
import {ModuleInstaller} from "../contracts/extensions/ModuleInstaller.sol";
import {HookInstaller} from "../contracts/extensions/HookInstaller.sol";
import {ValidatorInstaller} from "../contracts/extensions/ValidatorInstaller.sol";

contract BasicModularAccount is SoulWalletCore, ValidatorInstaller, HookInstaller, ModuleInstaller {
    uint256 private _initialized;

    modifier initializer() {
        require(_initialized == 0);
        _initialized = 1;
        _;
    }

    constructor(address _entryPoint) SoulWalletCore(_entryPoint) initializer {}

    function initialize(bytes32 owner, bytes calldata validatorAndData, address defaultFallback) external initializer {
        _addOwner(owner);
        _installValidator(address(bytes20(validatorAndData[:20])), validatorAndData[20:]);
        _setFallbackHandler(defaultFallback);
    }
}
