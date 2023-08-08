// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@source/SoulWalletFactory.sol";
import "@source/SoulWallet.sol";
import "@source/trustedContractManager/trustedModuleManager/TrustedModuleManager.sol";
import "@source/trustedContractManager/trustedPluginManager/TrustedPluginManager.sol";
import "@source/modules/SecurityControlModule/SecurityControlModule.sol";
import "@source/handler/DefaultCallbackHandler.sol";
import "@account-abstraction/contracts/core/EntryPoint.sol";
import "./DeployHelper.sol";

contract SingletonFactory is Script, DeployHelper {
    function run() public {
        deploySingletonFactory();
    }
}
