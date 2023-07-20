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

contract WalletDeployer is Script, DeployHelper {
    function run() public {
        vm.startBroadcast(privateKey);
        Network network = getNetwork();
        if (network == Network.Mainnet) {
            console.log("deploy soul wallet contract on mainnet");
            delpoy();
        }
        if (network == Network.Goerli) {
            console.log("deploy soul wallet contract on Goerli");
            delpoy();
        } else if (network == Network.Arbitrum) {
            console.log("deploy soul wallet contract on Arbitrum");
            delpoy();
        } else if (network == Network.Optimism) {
            console.log("deploy soul wallet contract on Optimism");
            delpoy();
        } else if (network == Network.ArbitrumGoerli) {
            console.log("deploy soul wallet contract on ArbitrumGoerli");
            delpoy();
        } else if (network == Network.Anvil) {
            console.log("deploy soul wallet contract on Anvil");
            deploySingletonFactory();
            delpoylocalEntryPoint();
            delpoy();
        } else if (network == Network.OptimismGoerli) {
            console.log("deploy soul wallet contract on OptimismGoerli");
            delpoy();
        } else {
            console.log("deploy soul wallet contract on testnet");
            delpoy();
        }
    }

    function delpoy() private {
        address soulwalletInstance =
            deploy("SoulwalletInstance", bytes.concat(type(SoulWallet).creationCode, abi.encode(ENTRYPOINT_ADDRESS)));
        address soulwalletFactoryAddress = deploy(
            "SoulwalletFactory", bytes.concat(type(SoulWalletFactory).creationCode, abi.encode(soulwalletInstance))
        );
        writeAddressToEnv("SOULWALLET_FACTORY_ADDRESS", soulwalletFactoryAddress);
        address managerAddress = vm.envAddress("MANAGER_ADDRESS");
        require(managerAddress != address(0), "MANAGER_ADDRESS not provided");

        address trustedModuleManager = deploy(
            "TrustedModuleManager", bytes.concat(type(TrustedModuleManager).creationCode, abi.encode(managerAddress))
        );

        address trustedPluginManager = deploy(
            "TrustedPluginManager", bytes.concat(type(TrustedPluginManager).creationCode, abi.encode(managerAddress))
        );

        deploy(
            "SecurityControlModule",
            bytes.concat(
                type(SecurityControlModule).creationCode, abi.encode(trustedModuleManager, trustedPluginManager)
            )
        );

        deploy("DefaultCallbackHandler", type(DefaultCallbackHandler).creationCode);
    }

    function delpoylocalEntryPoint() private {
        ENTRYPOINT_ADDRESS = deploy("EntryPoint", type(EntryPoint).creationCode);
    }
}
