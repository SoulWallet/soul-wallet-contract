// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@source/modules/keystore/OptimismKeyStoreProofModule/OpKnownStateRootWithHistory.sol";
import "@source/modules/keystore/ArbitrumKeyStoreModule/ArbKnownStateRootWithHistory.sol";
import "@source/modules/keystore/ArbitrumKeyStoreModule/L1BlockInfoPassing.sol";
import "@source/modules/keystore/KeystoreProof.sol";
import "@source/modules/keystore/OptimismKeyStoreProofModule/IL1Block.sol";
import "@source/modules/keystore/KeyStoreModule.sol";
import "@source/keystore/L1/KeyStore.sol";
import "@source/keystore/L1/KeyStoreStorage.sol";
import "@source/validator/KeystoreValidator.sol";
import "./DeployHelper.sol";

contract KeystoreDeployer is Script, DeployHelper {
    address private constant OP_L1_BLOCK_ADDRESS = 0x4200000000000000000000000000000000000015;

    //arb inbox contract address, https://developer.arbitrum.io/for-devs/useful-addresses
    address private constant ARB_ONE_INBOX_ADDRESS = 0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f;
    address private constant ARB_GOERLI_INBOX_ADDRESS = 0x6BEbC4925716945D46F0Ec336D5C2564F419682C;
    address private ARB_RUNTIME_INBOX_ADDRESS;

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
            ARB_RUNTIME_INBOX_ADDRESS = ARB_ONE_INBOX_ADDRESS;
            mainnetDeploy();
        } else if (network == Network.Goerli) {
            console.log("deploy keystore contract on Goerli");
            //Goerli deploy same logic as mainnet
            ARB_RUNTIME_INBOX_ADDRESS = ARB_GOERLI_INBOX_ADDRESS;
            mainnetDeploy();
            // deployKeystore();
        } else if (network == Network.Arbitrum) {
            console.log("deploy keystore contract on Arbitrum");
            arbDeploy();
        } else if (network == Network.ArbitrumGoerli) {
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

    function deployKeystore() private {
        require(address(SINGLETON_FACTORY).code.length > 0, "singleton factory not deployed");
        deploy("KeyStore", type(KeyStore).creationCode);
    }

    function mainnetDeploy() private {
        require(address(SINGLETON_FACTORY).code.length > 0, "singleton factory not deployed");
        address keyStoreValidator = deploy("KeyStoreValidator", type(KeystoreValidator).creationCode);
        writeAddressToEnv("KEYSTORE_VALIDATOR_ADDRESS", keyStoreValidator);
        address keyStoreStorage = deploy("KeyStoreStorage", type(KeyStoreStorage).creationCode);
        writeAddressToEnv("L1_KEYSTORE_STORAGE_ADDRESS", keyStoreStorage);
        address keyStore = deploy(
            "KeyStore", bytes.concat(type(KeyStore).creationCode, abi.encode(keyStoreValidator, keyStoreStorage))
        );
        writeAddressToEnv("L1_KEYSTORE_ADDRESS", keyStore);
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
        deployArbL1BlockInfoPassing();

        vm.stopBroadcast();
        // start broadcast using proxyAdminAddress
        vm.startBroadcast(proxyAdminPrivateKey);
        ITransparentUpgradeableProxy(keyStoreProxy).upgradeTo(keyStoreModule);
    }

    function deployArbL1BlockInfoPassing() private {
        // deploy arb l1blockinfo passing on l1
        address arbL1BlockInfoPassing = deploy(
            "L1BlockInfoPassing",
            bytes.concat(
                type(L1BlockInfoPassing).creationCode,
                abi.encode(EMPTY_ADDRESS, ARB_RUNTIME_INBOX_ADDRESS, proxyAdminAddress)
            )
        );
        writeAddressToEnv("ARB_L1_KEYSTORE_PASSING_ADDRESS", arbL1BlockInfoPassing);
    }

    function arbDeploy() private {
        l1KeyStoreAddress = vm.envAddress("L1_KEYSTORE_ADDRESS");
        console.log("using l1Keystore address", l1KeyStoreAddress);
        require(l1KeyStoreAddress != address(0), "L1_KEYSTORE_ADDRESS not provided");
        require(address(SINGLETON_FACTORY).code.length > 0, "singleton factory not deployed");
        arbL1KeyStorePassingAddress = vm.envAddress("ARB_L1_KEYSTORE_PASSING_ADDRESS");
        require(arbL1KeyStorePassingAddress != address(0), "ARB_L1_KEYSTORE_PASSING_ADDRESS not provided");
        // set l1 keystore address to adress(0) first, and then using owner to update true address
        address arbKnownStateRootWithHistory = deploy(
            "ArbKnownStateRootWithHistory",
            bytes.concat(type(ArbKnownStateRootWithHistory).creationCode, abi.encode(EMPTY_ADDRESS, proxyAdminAddress))
        );
        require(address(arbKnownStateRootWithHistory).code.length > 0, "arbKnownStateRootWithHistory deployed failed");

        address keystoreProof = deploy(
            "KeystoreProof",
            bytes.concat(type(KeystoreProof).creationCode, abi.encode(l1KeyStoreAddress, arbKnownStateRootWithHistory))
        );
        require(address(keystoreProof).code.length > 0, "keystoreProof deployed failed");

        address keyStoreModule =
            deploy("KeyStoreModule", bytes.concat(type(KeyStoreModule).creationCode, abi.encode(keystoreProof)));
        // deploy keystore module using proxy, the initial implemention address to SINGLE_USE_FACTORY_ADDRESS for keeping the same address with other network
        require(address(keyStoreModule).code.length > 0, "keyStoreModule deployed failed");
        address keyStoreProxy = deploy(
            "KeyStoreModuleProxy",
            bytes.concat(
                type(TransparentUpgradeableProxy).creationCode,
                abi.encode(address(SINGLETON_FACTORY), proxyAdminAddress, emptyBytes)
            )
        );
        require(address(keyStoreProxy).code.length > 0, "keyStoreProxy deployed failed");
        vm.stopBroadcast();
        // start broadcast using proxyAdminAddress
        vm.startBroadcast(proxyAdminPrivateKey);
        ITransparentUpgradeableProxy(keyStoreProxy).upgradeTo(keyStoreModule);
        // setup l1 target
        ArbKnownStateRootWithHistory(arbKnownStateRootWithHistory).updateL1Target(arbL1KeyStorePassingAddress);
        writeAddressToEnv("ARB_KNOWN_STATE_ROOT_WITH_HISTORY_ADDRESS", arbKnownStateRootWithHistory);
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
