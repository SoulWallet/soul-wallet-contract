// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ValidatorManager} from "@soulwallet-core/contracts/base/ValidatorManager.sol";
import {ISoulWalletValidatorManager} from "../interfaces/ISoulWalletValidatorManager.sol";

abstract contract SoulWalletValidatorManager is ISoulWalletValidatorManager, ValidatorManager {
    function installValidator(bytes calldata validatorAndData) external virtual override {
        validatorManagementAccess();
        _installValidator(address(bytes20(validatorAndData[:20])), validatorAndData[20:]);
    }
}
