// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@source/modules/keystore/KeyStoreModule.sol";
import "@source/modules/keystore/optimism/OpMerkleRootHistory.sol";
import "@source/modules/keystore/optimism/OpKeyStoreCrossChainMerkleRootManager.sol";
import "@source/modules/keystore/arbitrum/ArbMerkleRootHistory.sol";
import "@source/modules/keystore/arbitrum/ArbKeyStoreCrossChainMerkleRootManager.sol";
import "@source/modules/keystore/scroll/ScrollMerkleRootHistory.sol";
import "@source/modules/keystore/scroll/ScrollKeyStoreCrossChainMerkleRootManager.sol";
import "@source/modules/keystore/KeyStoreMerkleProof.sol";
import "@source/keystore/L1/KeyStore.sol";
import "@source/keystore/L1/KeyStoreStorage.sol";
import "@source/validator/KeyStoreValidator.sol";
import "./DeployHelper.sol";

contract KeyStoreDeployer is Script, DeployHelper {
    //arb inbox contract address, https://developer.arbitrum.io/for-devs/useful-addresses
    address private constant ARB_ONE_INBOX_ADDRESS = 0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f;
    address private constant ARB_GOERLI_INBOX_ADDRESS = 0x6BEbC4925716945D46F0Ec336D5C2564F419682C;
    address private constant ARB_SEPOLIA_INBOX_ADDRESS = 0xaAe29B0366299461418F5324a79Afc425BE5ae21;
    address private ARB_RUNTIME_INBOX_ADDRESS;

    //https://community.optimism.io/docs/useful-tools/networks/#op-mainnet
    address private constant OP_MAINNET_L1_CROSS_DOMAIN_MESSENGER_ADDRESS = 0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1;
    address private constant OP_GOERLI_L1_CROSS_DOMAIN_MESSENGER_ADDRESS = 0x5086d1eEF304eb5284A0f6720f79403b4e9bE294;
    address private constant OP_SEPOLIA_L1_CROSS_DOMAIN_MESSENGER_ADDRESS = 0x58Cc85b8D04EA49cC6DBd3CbFFd00B4B8D6cb3ef;
    address private OP_L1_CROSS_DOMAIN_MESSENGER_ADDRESS;
    //https://docs.scroll.io/en/developers/scroll-contracts/
    address private constant SCROLL_MAINNET_L1_CROSS_DOMAIN_MESSENGER_ADDRESS =
        0x6774Bcbd5ceCeF1336b5300fb5186a12DDD8b367;
    address private constant SCROLL_SEPOLIA_L1_CROSS_DOMAIN_MESSENGER_ADDRESS =
        0x50c7d3e7f7c656493D1D76aaa1a836CedfCBB16A;
    address private constant SCROLL_MAINNET_L2_CROSS_DOMAIN_MESSENGER_ADDRESS =
        0x781e90f1c8Fc4611c9b7497C3B47F99Ef6969CbC;
    address private constant SCROLL_SEPOLIA_L2_CROSS_DOMAIN_MESSENGER_ADDRESS =
        0xBa50f5340FB9F3Bd074bD638c9BE13eCB36E603d;
    address private SCROLL_L1_CROSS_DOMAIN_MESSENGER_ADDRESS;
    address private SCROLL_L2_CROSS_DOMAIN_MESSENGER_ADDRESS;

    address l1KeyStoreAddress;
    address opKeyStoreCrossChainMerkleRootManagerAddress;
    address arbKeyStoreCrossChainMerkleRootManagerAddress;
    address scrollKeyStoreCrossChainMerkleRootManagerAddress;

    address l1KeyStoreStorageAddress;
    address proxyAdminAddress;
    uint256 proxyAdminPrivateKey;

    address keyStoreAdminAddress;
    uint256 keyStoreAdminPrivateKey;

    function run() public {
        proxyAdminPrivateKey = vm.envUint("PROXY_ADMIN_PRIVATE_KEY");
        proxyAdminAddress = vm.addr(proxyAdminPrivateKey);

        keyStoreAdminPrivateKey = vm.envUint("KEYSTORE_ADMIN_PRIVATE_KEY");
        keyStoreAdminAddress = vm.addr(keyStoreAdminPrivateKey);

        require(proxyAdminAddress != address(0), "proxyAdminAddress not provided");
        vm.startBroadcast(privateKey);
        Network network = getNetwork();
        string memory networkName = NetWorkLib.getNetworkName();
        console.log("deploy keystore contract on ", networkName);

        if (network == Network.Mainnet) {
            ARB_RUNTIME_INBOX_ADDRESS = ARB_ONE_INBOX_ADDRESS;
            mainnetDeploy();
        } else if (network == Network.Goerli) {
            ARB_RUNTIME_INBOX_ADDRESS = ARB_GOERLI_INBOX_ADDRESS;
            OP_L1_CROSS_DOMAIN_MESSENGER_ADDRESS = OP_GOERLI_L1_CROSS_DOMAIN_MESSENGER_ADDRESS;
            OP_L1_CROSS_DOMAIN_MESSENGER_ADDRESS = OP_SEPOLIA_L1_CROSS_DOMAIN_MESSENGER_ADDRESS;
            SCROLL_L1_CROSS_DOMAIN_MESSENGER_ADDRESS = SCROLL_SEPOLIA_L1_CROSS_DOMAIN_MESSENGER_ADDRESS;
            mainnetDeploy();
        } else if (network == Network.Sepolia) {
            ARB_RUNTIME_INBOX_ADDRESS = ARB_SEPOLIA_INBOX_ADDRESS;
            OP_L1_CROSS_DOMAIN_MESSENGER_ADDRESS = OP_SEPOLIA_L1_CROSS_DOMAIN_MESSENGER_ADDRESS;
            SCROLL_L1_CROSS_DOMAIN_MESSENGER_ADDRESS = SCROLL_SEPOLIA_L1_CROSS_DOMAIN_MESSENGER_ADDRESS;
            mainnetDeploy();
        } else if (
            network == Network.Arbitrum || network == Network.ArbitrumGoerli || network == Network.ArbitrumSepolia
        ) {
            arbDeploy();
        } else if (
            network == Network.Optimism || network == Network.OptimismGoerli || network == Network.OptimismSepolia
                || network == Network.BaseSepolia
        ) {
            opDeploy();
        } else if (network == Network.Scroll || network == Network.ScrollSepolia) {
            scrollDeploy();
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
        address keyStoreValidator = deploy("KeyStoreValidator", type(KeyStoreValidator).creationCode);
        writeAddressToEnv("KEYSTORE_VALIDATOR_ADDRESS", keyStoreValidator);
        // address keyStoreStorage = deploy("KeyStoreStorage", type(KeyStoreStorage).creationCode);
        address keyStoreStorage = deploy(
            "KeyStoreStorage", bytes.concat(type(KeyStoreStorage).creationCode, abi.encode(keyStoreAdminAddress))
        );

        writeAddressToEnv("L1_KEYSTORE_STORAGE_ADDRESS", keyStoreStorage);
        address keyStore = deploy(
            "KeyStore",
            bytes.concat(
                type(KeyStore).creationCode, abi.encode(keyStoreValidator, keyStoreStorage, keyStoreAdminAddress)
            )
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
        // calcuate proxy admin contract in TransparentUpgradeableProxy
        address proxyAdminContractAddress = getCreateAddress(keyStoreProxy, 1);
        console.log("proxyAdminContractAddress", proxyAdminContractAddress);
        deployArbKeyStoreCrossChainMerkleRootManager(address(keyStoreStorage));
        deployOpKeyStoreCrossChainMerkleRootManager(address(keyStoreStorage));
        deployScrollKeyStoreCrossChainMerkleRootManager(address(keyStoreStorage));

        vm.stopBroadcast();
        // start broadcast using proxyAdminAddress
        vm.startBroadcast(proxyAdminPrivateKey);

        bytes memory _data;
        ProxyAdmin(proxyAdminContractAddress).upgradeAndCall(
            ITransparentUpgradeableProxy(keyStoreProxy), keyStoreModule, _data
        );
        vm.stopBroadcast();
        vm.startBroadcast(keyStoreAdminPrivateKey);
        KeyStoreStorage(keyStoreStorage).setDefaultKeystoreAddress(keyStore);
    }

    function deployArbKeyStoreCrossChainMerkleRootManager(address _keyStoreStorage) private {
        // deploy ArbKeyStoreCrossChainMerkleRootManager on l1
        require(_keyStoreStorage != address(0), "keyStoreStorage address empty");
        address arbKeyStoreCrossChainMerkleRootManager = deploy(
            "ArbKeyStoreCrossChainMerkleRootManager",
            bytes.concat(
                type(ArbKeyStoreCrossChainMerkleRootManager).creationCode,
                abi.encode(EMPTY_ADDRESS, _keyStoreStorage, ARB_RUNTIME_INBOX_ADDRESS, proxyAdminAddress)
            )
        );
        writeAddressToEnv("ARB_KEYSTORE_CROSSCHAIN_MERKLEROOT_MANAGER_ADDRESS", arbKeyStoreCrossChainMerkleRootManager);
    }

    function deployOpKeyStoreCrossChainMerkleRootManager(address _keyStoreStorage) private {
        require(OP_L1_CROSS_DOMAIN_MESSENGER_ADDRESS != address(0), "OP_L1_CROSS_DOMAIN_MESSENGER_ADDRESS empty");
        require(_keyStoreStorage != address(0), "keyStoreStorage address empty");
        address opKeyStoreCrossChainMerkleRootManager = deploy(
            "OpKeyStoreCrossChainMerkleRootManager",
            bytes.concat(
                type(OpKeyStoreCrossChainMerkleRootManager).creationCode,
                abi.encode(EMPTY_ADDRESS, _keyStoreStorage, OP_L1_CROSS_DOMAIN_MESSENGER_ADDRESS, proxyAdminAddress)
            )
        );
        writeAddressToEnv("OP_KEYSTORE_CROSSCHAIN_MERKLEROOT_MANAGER_ADDRESS", opKeyStoreCrossChainMerkleRootManager);
    }

    function deployScrollKeyStoreCrossChainMerkleRootManager(address _keyStoreStorage) private {
        require(
            SCROLL_L1_CROSS_DOMAIN_MESSENGER_ADDRESS != address(0), "SCROLL_L1_CROSS_DOMAIN_MESSENGER_ADDRESS empty"
        );
        require(_keyStoreStorage != address(0), "keyStoreStorage address empty");
        address scrollKeyStoreCrossChainMerkleRootManager = deploy(
            "ScrollKeyStoreCrossChainMerkleRootManager",
            bytes.concat(
                type(ScrollKeyStoreCrossChainMerkleRootManager).creationCode,
                abi.encode(EMPTY_ADDRESS, _keyStoreStorage, SCROLL_L1_CROSS_DOMAIN_MESSENGER_ADDRESS, proxyAdminAddress)
            )
        );
        writeAddressToEnv(
            "SCROLL_KEYSTORE_CROSSCHAIN_MERKLEROOT_MANAGER_ADDRESS", scrollKeyStoreCrossChainMerkleRootManager
        );
    }

    function arbDeploy() private {
        l1KeyStoreStorageAddress = vm.envAddress("L1_KEYSTORE_STORAGE_ADDRESS");
        console.log("using l1KeyStoreStorageAddress address", l1KeyStoreStorageAddress);
        require(l1KeyStoreStorageAddress != address(0), "L1_KEYSTORE_STORAGE_ADDRESS not provided");
        require(address(SINGLETON_FACTORY).code.length > 0, "singleton factory not deployed");
        arbKeyStoreCrossChainMerkleRootManagerAddress =
            vm.envAddress("ARB_KEYSTORE_CROSSCHAIN_MERKLEROOT_MANAGER_ADDRESS");
        require(
            arbKeyStoreCrossChainMerkleRootManagerAddress != address(0),
            "ARB_KEYSTORE_CROSSCHAIN_MERKLEROOT_MANAGER_ADDRESS not provided"
        );
        // set l1 keystore address to adress(0) first, and then using owner to update true address
        address arbMerkleRootHistory = deploy(
            "ArbMerkleRootHistory",
            bytes.concat(type(ArbMerkleRootHistory).creationCode, abi.encode(EMPTY_ADDRESS, proxyAdminAddress))
        );
        require(address(arbMerkleRootHistory).code.length > 0, "arbMerkleRootHistory deployed failed");

        address keystoreProof = deploy(
            "ArbKeyStoreMerkleProof",
            bytes.concat(type(KeyStoreMerkleProof).creationCode, abi.encode(arbMerkleRootHistory))
        );
        require(address(keystoreProof).code.length > 0, "keystoreProof deployed failed");

        address keyStoreModule =
            deploy("ArbKeyStoreModule", bytes.concat(type(KeyStoreModule).creationCode, abi.encode(keystoreProof)));
        // deploy keystore module using proxy, the initial implemention address to SINGLE_USE_FACTORY_ADDRESS for keeping the same address with other network
        require(address(keyStoreModule).code.length > 0, "keyStoreModule deployed failed");
        address keyStoreProxy = deploy(
            "KeyStoreModuleProxy",
            bytes.concat(
                type(TransparentUpgradeableProxy).creationCode,
                abi.encode(address(SINGLETON_FACTORY), proxyAdminAddress, emptyBytes)
            )
        );
        address proxyAdminContractAddress = getCreateAddress(keyStoreProxy, 1);
        console.log("arb proxyAdminContractAddress", proxyAdminContractAddress);
        require(address(keyStoreProxy).code.length > 0, "keyStoreProxy deployed failed");
        vm.stopBroadcast();
        // start broadcast using proxyAdminAddress
        vm.startBroadcast(proxyAdminPrivateKey);

        bytes memory _data;
        ProxyAdmin(proxyAdminContractAddress).upgradeAndCall(
            ITransparentUpgradeableProxy(keyStoreProxy), keyStoreModule, _data
        );
        // setup l1 target
        ArbMerkleRootHistory(arbMerkleRootHistory).updateL1Target(arbKeyStoreCrossChainMerkleRootManagerAddress);
        writeAddressToEnv("ARB_MERKLE_ROOT_HISTORY_ADDRESS", arbMerkleRootHistory);
    }

    function opDeploy() private {
        l1KeyStoreStorageAddress = vm.envAddress("L1_KEYSTORE_STORAGE_ADDRESS");
        require(l1KeyStoreStorageAddress != address(0), "L1_KEYSTORE_STORAGE_ADDRESS not provided");

        require(address(SINGLETON_FACTORY).code.length > 0, "singleton factory not deployed");

        opKeyStoreCrossChainMerkleRootManagerAddress =
            vm.envAddress("OP_KEYSTORE_CROSSCHAIN_MERKLEROOT_MANAGER_ADDRESS");
        require(
            opKeyStoreCrossChainMerkleRootManagerAddress != address(0),
            "OP_KEYSTORE_CROSSCHAIN_MERKLEROOT_MANAGER_ADDRESS not provided"
        );
        // set l1 keystore address to adress(0) first, and then using owner to update true address
        address opMerkleRootHistory = deploy(
            "OpMerkleRootHistory",
            bytes.concat(type(OpMerkleRootHistory).creationCode, abi.encode(EMPTY_ADDRESS, proxyAdminAddress))
        );
        require(address(opMerkleRootHistory).code.length > 0, "opMerkleRootHistory deployed failed");

        address keystoreProof = deploy(
            "OpKeyStoreMerkleProof",
            bytes.concat(type(KeyStoreMerkleProof).creationCode, abi.encode(opMerkleRootHistory))
        );
        require(address(keystoreProof).code.length > 0, "keystoreProof deployed failed");

        address keyStoreModule =
            deploy("OpKeyStoreModule", bytes.concat(type(KeyStoreModule).creationCode, abi.encode(keystoreProof)));
        // deploy keystore module using proxy, the initial implemention address to SINGLE_USE_FACTORY_ADDRESS for keeping the same address with other network
        require(address(keyStoreModule).code.length > 0, "keyStoreModule deployed failed");
        address keyStoreProxy = deploy(
            "KeyStoreModuleProxy",
            bytes.concat(
                type(TransparentUpgradeableProxy).creationCode,
                abi.encode(address(SINGLETON_FACTORY), proxyAdminAddress, emptyBytes)
            )
        );
        address proxyAdminContractAddress = getCreateAddress(keyStoreProxy, 1);
        console.log("op proxyAdminContractAddress", proxyAdminContractAddress);
        require(address(keyStoreProxy).code.length > 0, "keyStoreProxy deployed failed");
        vm.stopBroadcast();
        // start broadcast using proxyAdminAddress
        vm.startBroadcast(proxyAdminPrivateKey);
        bytes memory _data;
        ProxyAdmin(proxyAdminContractAddress).upgradeAndCall(
            ITransparentUpgradeableProxy(keyStoreProxy), keyStoreModule, _data
        );

        // setup l1 target
        OpMerkleRootHistory(opMerkleRootHistory).updateL1Target(opKeyStoreCrossChainMerkleRootManagerAddress);
        writeAddressToEnv("OP_MERKLE_ROOT_HISTORY_ADDRESS", opMerkleRootHistory);
    }

    function scrollDeploy() private {
        l1KeyStoreStorageAddress = vm.envAddress("L1_KEYSTORE_STORAGE_ADDRESS");
        require(l1KeyStoreStorageAddress != address(0), "L1_KEYSTORE_STORAGE_ADDRESS not provided");

        require(address(SINGLETON_FACTORY).code.length > 0, "singleton factory not deployed");

        scrollKeyStoreCrossChainMerkleRootManagerAddress =
            vm.envAddress("SCROLL_KEYSTORE_CROSSCHAIN_MERKLEROOT_MANAGER_ADDRESS");
        require(
            scrollKeyStoreCrossChainMerkleRootManagerAddress != address(0),
            "SCROLL_KEYSTORE_CROSSCHAIN_MERKLEROOT_MANAGER_ADDRESS not provided"
        );
        Network network = getNetwork();
        if (network == Network.Scroll) {
            SCROLL_L2_CROSS_DOMAIN_MESSENGER_ADDRESS = SCROLL_MAINNET_L2_CROSS_DOMAIN_MESSENGER_ADDRESS;
        } else if (network == Network.ScrollSepolia) {
            SCROLL_L2_CROSS_DOMAIN_MESSENGER_ADDRESS = SCROLL_SEPOLIA_L2_CROSS_DOMAIN_MESSENGER_ADDRESS;
        }
        // set l1 keystore address to adress(0) first, and then using owner to update true address
        address scrollMerkleRootHistory = deploy(
            "ScrollMerkleRootHistory",
            bytes.concat(
                type(ScrollMerkleRootHistory).creationCode,
                abi.encode(EMPTY_ADDRESS, proxyAdminAddress, SCROLL_L2_CROSS_DOMAIN_MESSENGER_ADDRESS)
            )
        );
        require(address(scrollMerkleRootHistory).code.length > 0, "scrollMerkleRootHistory deployed failed");

        address keystoreProof = deploy(
            "ScrollKeyStoreMerkleProof",
            bytes.concat(type(KeyStoreMerkleProof).creationCode, abi.encode(scrollMerkleRootHistory))
        );
        require(address(keystoreProof).code.length > 0, "keystoreProof deployed failed");

        address keyStoreModule =
            deploy("ScrollKeyStoreModule", bytes.concat(type(KeyStoreModule).creationCode, abi.encode(keystoreProof)));
        // deploy keystore module using proxy, the initial implemention address to SINGLE_USE_FACTORY_ADDRESS for keeping the same address with other network
        require(address(keyStoreModule).code.length > 0, "keyStoreModule deployed failed");
        address keyStoreProxy = deploy(
            "KeyStoreModuleProxy",
            bytes.concat(
                type(TransparentUpgradeableProxy).creationCode,
                abi.encode(address(SINGLETON_FACTORY), proxyAdminAddress, emptyBytes)
            )
        );
        address proxyAdminContractAddress = getCreateAddress(keyStoreProxy, 1);
        console.log("scroll proxyAdminContractAddress", proxyAdminContractAddress);
        require(address(keyStoreProxy).code.length > 0, "keyStoreProxy deployed failed");
        vm.stopBroadcast();
        // start broadcast using proxyAdminAddress
        vm.startBroadcast(proxyAdminPrivateKey);
        bytes memory _data;
        ProxyAdmin(proxyAdminContractAddress).upgradeAndCall(
            ITransparentUpgradeableProxy(keyStoreProxy), keyStoreModule, _data
        );

        // setup l1 target
        ScrollMerkleRootHistory(scrollMerkleRootHistory).updateL1Target(
            scrollKeyStoreCrossChainMerkleRootManagerAddress
        );
        writeAddressToEnv("SCROLL_MERKLE_ROOT_HISTORY_ADDRESS", scrollMerkleRootHistory);
    }
}
