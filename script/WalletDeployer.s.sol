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
    address deployer;
    uint256 privateKey;
    address private ENTRYPOINT_ADDRESS = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    function run() public {
        privateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        Network network = getNetwork();
        if (network == Network.Mainnet) {
            console.log("deploy soul wallet contract on mainnet");
            delpoy();
        } else if (network == Network.Arbitrum) {
            console.log("deploy soul wallet contract on Arbitrum");
            delpoy();
        } else if (network == Network.Optimism) {
            console.log("deploy soul wallet contract on Optimism");
            delpoy();
        } else if (network == Network.Anvil) {
            console.log("deploy soul wallet contract on Anvil");
            deploySingletonFactory();
            delpoylocalEntryPoint();
            delpoy();
        } else {
            console.log("deploy soul wallet contract on testnet");
            delpoy();
        }
    }

    function deploySingletonFactory() internal {
        if (address(SINGLETON_FACTORY).code.length == 0) {
            console.log("send 1 eth to SINGLE_USE_FACTORY_ADDRESS");
            string[] memory sendEthInputs = new string[](7);
            sendEthInputs[0] = "cast";
            sendEthInputs[1] = "send";
            sendEthInputs[2] = "--private-key";
            sendEthInputs[3] = LibString.toHexString(privateKey);
            // ABI encoded "gm", as a hex string
            sendEthInputs[4] = LibString.toHexString(SINGLE_USE_FACTORY_ADDRESS);
            sendEthInputs[5] = "--value";
            sendEthInputs[6] = "1ether";
            bytes memory sendEthRes = vm.ffi(sendEthInputs);
            console.log("deploy singleton factory");
            string[] memory inputs = new string[](3);
            inputs[0] = "cast";
            inputs[1] = "publish";
            // ABI encoded "gm", as a hex string
            inputs[2] =
                "0xf9016c8085174876e8008303c4d88080b90154608060405234801561001057600080fd5b50610134806100206000396000f3fe6080604052348015600f57600080fd5b506004361060285760003560e01c80634af63f0214602d575b600080fd5b60cf60048036036040811015604157600080fd5b810190602081018135640100000000811115605b57600080fd5b820183602082011115606c57600080fd5b80359060200191846001830284011164010000000083111715608d57600080fd5b91908080601f016020809104026020016040519081016040528093929190818152602001838380828437600092019190915250929550509135925060eb915050565b604080516001600160a01b039092168252519081900360200190f35b6000818351602085016000f5939250505056fea26469706673582212206b44f8a82cb6b156bfcc3dc6aadd6df4eefd204bc928a4397fd15dacf6d5320564736f6c634300060200331b83247000822470";
            bytes memory res = vm.ffi(inputs);
        }
    }

    function delpoy() private {
        address soulwalletInstance =
            deploy("SoulwalletInstance", bytes.concat(type(SoulWallet).creationCode, abi.encode(ENTRYPOINT_ADDRESS)));
        deploy("SoulwalletFactory", bytes.concat(type(SoulWalletFactory).creationCode, abi.encode(soulwalletInstance)));
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
