// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@source/modules/keystore/OptimismKeyStoreProofModule/OpKnownStateRootWithHistory.sol";
import "@source/modules/keystore/ArbitrumKeyStoreModule/ArbKnownStateRootWithHistory.sol";
import "@source/modules/keystore/KeystoreProof.sol";
import "@source/modules/keystore/OptimismKeyStoreProofModule/IL1Block.sol";
import "@source/modules/keystore/KeyStoreModule.sol";
import "@source/keystore/L1/KeyStore.sol";
import "./DeployHelper.sol";

contract KeystoreDeployer is Script, DeployHelper {
    address deployer;
    uint256 privateKey;
    address private constant OP_L1_BLOCK_ADDRESS = 0x4200000000000000000000000000000000000015;

    address l1KeyStoreAddress;
    address proxyAdminAddress;
    uint256 proxyAdminPrivateKey;
    address arbL1KeyStorePassingAddress;

    function run() public {
        privateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        proxyAdminPrivateKey = vm.envUint("PROXY_ADMIN_PRIVATE_KEY");
        proxyAdminAddress = vm.addr(proxyAdminPrivateKey);
        require(proxyAdminAddress != address(0), "proxyAdminAddress not provided");
        deployer = vm.addr(privateKey);
        console.log("deployer address", deployer);
        vm.startBroadcast(privateKey);
        Network network = getNetwork();
        if (network == Network.Mainnet) {
            console.log("deploy keystore contract on mainnet");
            mainnetDeploy();
        } else if (network == Network.Arbitrum) {
            console.log("deploy keystore contract on Arbitrum");
            arbDeploy();
        } else if (network == Network.Optimism) {
            console.log("deploy keystore contract on Optimism");
            opDeploy();
        } else if (network == Network.Anvil) {
            console.log("deploy keystore contract on Anvil");
            AnvilDeploy();
        } else {
            console.log("deploy keystore contract on testnet");
        }
    }

    function AnvilDeploy() private {
        deploySingletonFactory();
        // opDeploy();
        // arbDeploy();
        mainnetDeploy();
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

    function mainnetDeploy() private {
        require(address(SINGLETON_FACTORY).code.length > 0, "singleton factory not deployed");
        address keyStore = deploy("KeyStore", type(KeyStore).creationCode);
        address keyStoreModule =
            deploy("KeyStoreModule", bytes.concat(type(KeyStoreModule).creationCode, abi.encode(keyStore)));
        // deploy keystore module using proxy, the initial implemention address to SINGLE_USE_FACTORY_ADDRESS for keeping the same address with other network
        address keyStoreProxy = deploy(
            "KeyStoreModuleProxy",
            bytes.concat(
                type(TransparentUpgradeableProxy).creationCode,
                abi.encode(address(SINGLETON_FACTORY), proxyAdminAddress, emptyBytes)
            )
        );
        vm.stopBroadcast();
        // start broadcast using proxyAdminAddress
        vm.startBroadcast(proxyAdminPrivateKey);
        ITransparentUpgradeableProxy(keyStoreProxy).upgradeTo(keyStoreModule);
    }

    function arbDeploy() private {
        l1KeyStoreAddress = vm.envAddress("L1_KEYSTORE_ADDRESS");
        require(l1KeyStoreAddress != address(0), "L1_KEYSTORE_ADDRESS not provided");
        require(address(SINGLETON_FACTORY).code.length > 0, "singleton factory not deployed");
        arbL1KeyStorePassingAddress = vm.envAddress("ARB_L1_KEYSTORE_PASSING_ADDRESS");

        address arbKnownStateRootWithHistory = deploy(
            "ArbKnownStateRootWithHistory",
            bytes.concat(type(ArbKnownStateRootWithHistory).creationCode, abi.encode(arbL1KeyStorePassingAddress))
        );

        address keystoreProof = deploy(
            "KeystoreProof",
            bytes.concat(type(KeystoreProof).creationCode, abi.encode(l1KeyStoreAddress, arbKnownStateRootWithHistory))
        );

        address keyStoreModule =
            deploy("KeyStoreModule", bytes.concat(type(KeyStoreModule).creationCode, abi.encode(keystoreProof)));
        // deploy keystore module using proxy, the initial implemention address to SINGLE_USE_FACTORY_ADDRESS for keeping the same address with other network
        address keyStoreProxy = deploy(
            "KeyStoreModuleProxy",
            bytes.concat(
                type(TransparentUpgradeableProxy).creationCode,
                abi.encode(address(SINGLETON_FACTORY), proxyAdminAddress, emptyBytes)
            )
        );
        vm.stopBroadcast();
        // start broadcast using proxyAdminAddress
        vm.startBroadcast(proxyAdminPrivateKey);
        ITransparentUpgradeableProxy(keyStoreProxy).upgradeTo(keyStoreModule);
    }

    function opDeploy() private {
        l1KeyStoreAddress = vm.envAddress("L1_KEYSTORE_ADDRESS");
        require(l1KeyStoreAddress != address(0), "L1_KEYSTORE_ADDRESS not provided");

        require(address(SINGLETON_FACTORY).code.length > 0, "singleton factory not deployed");

        address opKnownStateRootWithHistory = deploy(
            "OpKnownStateRootWithHistory",
            bytes.concat(type(OpKnownStateRootWithHistory).creationCode, abi.encode(OP_L1_BLOCK_ADDRESS))
        );

        address keystoreProof = deploy(
            "KeystoreProof",
            bytes.concat(type(KeystoreProof).creationCode, abi.encode(l1KeyStoreAddress, opKnownStateRootWithHistory))
        );

        address keyStoreModule =
            deploy("KeyStoreModule", bytes.concat(type(KeyStoreModule).creationCode, abi.encode(keystoreProof)));
        // deploy keystore module using proxy, the initial implemention address to SINGLE_USE_FACTORY_ADDRESS for keeping the same address with other network
        address keyStoreProxy = deploy(
            "KeyStoreModuleProxy",
            bytes.concat(
                type(TransparentUpgradeableProxy).creationCode,
                abi.encode(address(SINGLETON_FACTORY), proxyAdminAddress, emptyBytes)
            )
        );
        vm.stopBroadcast();
        // start broadcast using proxyAdminAddress
        vm.startBroadcast(proxyAdminPrivateKey);
        ITransparentUpgradeableProxy(keyStoreProxy).upgradeTo(keyStoreModule);
    }
}
