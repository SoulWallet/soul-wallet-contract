// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@source/factory/SoulWalletFactory.sol";
import "@source/SoulWallet.sol";
import "@source/modules/securityControlModule/trustedContractManager/trustedModuleManager/TrustedModuleManager.sol";
import "@source/modules/securityControlModule/trustedContractManager/trustedHookManager/TrustedHookManager.sol";
import
    "@source/modules/securityControlModule/trustedContractManager/trustedValidatorManager/TrustedValidatorManager.sol";
import "@source/modules/securityControlModule/SecurityControlModule.sol";
import "@source/abstract/DefaultCallbackHandler.sol";
import {SoulWalletDefaultValidator} from "@source/validator/SoulWalletDefaultValidator.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import "./DeployHelper.sol";

contract WalletDeployer is Script, DeployHelper {
    function run() public {
        vm.startBroadcast(privateKey);
        Network network = getNetwork();
        string memory networkName = NetWorkLib.getNetworkName();
        console.log("deploy soul wallet contract on ", networkName);
        if (network == Network.Anvil) {
            deploySingletonFactory();
            deployLocalEntryPoint();
        }
        deploy();
    }

    function deploy() private {
        address soulWalletDefaultValidator =
            deploy("SoulWalletDefaultValidator", type(SoulWalletDefaultValidator).creationCode);
        writeAddressToEnv("SOUL_WALLET_DEFAULT_VALIDATOR", soulWalletDefaultValidator);
        address soulwalletInstance = deploy(
            "SoulwalletInstance",
            bytes.concat(type(SoulWallet).creationCode, abi.encode(ENTRYPOINT_ADDRESS, soulWalletDefaultValidator))
        );
        address soulwalletFactoryOwner = vm.envAddress("SOULWALLET_FACTORY_OWNER");
        address soulwalletFactoryAddress = deploy(
            "SoulwalletFactory",
            bytes.concat(
                type(SoulWalletFactory).creationCode,
                abi.encode(soulwalletInstance, ENTRYPOINT_ADDRESS, soulwalletFactoryOwner)
            )
        );
        writeAddressToEnv("SOULWALLET_FACTORY_ADDRESS", soulwalletFactoryAddress);
        address managerAddress = vm.envAddress("MANAGER_ADDRESS");
        require(managerAddress != address(0), "MANAGER_ADDRESS not provided");

        address trustedModuleManager = deploy(
            "TrustedModuleManager", bytes.concat(type(TrustedModuleManager).creationCode, abi.encode(managerAddress))
        );

        address trustedHookManager = deploy(
            "TrustedHookManager", bytes.concat(type(TrustedHookManager).creationCode, abi.encode(managerAddress))
        );

        address trustedValidatorManager = deploy(
            "TrustedValidatorManager",
            bytes.concat(type(TrustedValidatorManager).creationCode, abi.encode(managerAddress))
        );

        deploy(
            "SecurityControlModule",
            bytes.concat(
                type(SecurityControlModule).creationCode,
                abi.encode(trustedModuleManager, trustedHookManager, trustedValidatorManager)
            )
        );

        deploy("DefaultCallbackHandler", type(DefaultCallbackHandler).creationCode);
    }

    function deployLocalEntryPoint() private {
        ENTRYPOINT_ADDRESS = deploy("EntryPoint", type(EntryPoint).creationCode);
    }
}
