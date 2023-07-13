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
    address private constant OP_L1_BLOCK_ADDRESS = 0x4200000000000000000000000000000000000015;

    address l1KeyStoreAddress;
    address proxyAdminAddress;
    uint256 proxyAdminPrivateKey;
    address arbL1KeyStorePassingAddress;

    function run() public {
        proxyAdminPrivateKey = vm.envUint("PROXY_ADMIN_PRIVATE_KEY");
        proxyAdminAddress = vm.addr(proxyAdminPrivateKey);
        require(proxyAdminAddress != address(0), "proxyAdminAddress not provided");
        vm.startBroadcast(privateKey);
        Network network = getNetwork();
        if (network == Network.Mainnet) {
            console.log("deploy keystore contract on mainnet");
            mainnetDeploy();
        } else if (network == Network.Goerli) {
            console.log("deploy keystore contract on Goerli");
            //Goerli deploy same logic as mainnet
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
        } else if (network == Network.OptimismGoerli) {
            console.log("deploy soul wallet contract on OptimismGoerli");
            opDeploy();
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
        require(l1KeyStoreAddress.code.length > 0, "l1KeyStoreAddress not deployed");
        require(address(SINGLETON_FACTORY).code.length > 0, "singleton factory not deployed");
        arbL1KeyStorePassingAddress = vm.envAddress("ARB_L1_KEYSTORE_PASSING_ADDRESS");
        require(arbL1KeyStorePassingAddress != address(0), "ARB_L1_KEYSTORE_PASSING_ADDRESS not provided");
        require(arbL1KeyStorePassingAddress.code.length > 0, "arbL1KeyStorePassingAddress needs be deployed");

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
