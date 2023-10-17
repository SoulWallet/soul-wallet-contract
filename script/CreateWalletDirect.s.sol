// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@source/SoulWalletFactory.sol";
import "@source/SoulWallet.sol";
import "@source/keystore/L1/KeyStore.sol";
import "@account-abstraction/contracts/core/EntryPoint.sol";
import "./DeployHelper.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@source/modules/keystore/KeyStoreModule.sol";
import "@source/modules/keystore/OptimismKeyStoreProofModule/OpKnownStateRootWithHistory.sol";
import "@source/modules/keystore/KeystoreProof.sol";
import "@source/libraries/TypeConversion.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {NetWorkLib} from "./DeployHelper.sol";

contract CreateWalletDirect is Script {
    using MessageHashUtils for bytes32;
    using TypeConversion for address;

    uint256 guardianThreshold = 1;
    uint64 initialGuardianSafePeriod = 2 days;

    address walletSigner;
    uint256 walletSingerPrivateKey;

    address newWalletSigner;
    uint256 newWalletSingerPrivateKey;

    address guardianAddress;
    uint256 guardianPrivateKey;

    address securityControlModuleAddress;

    address keystoreModuleAddress;

    address defaultCallbackHandler;

    SoulWalletFactory soulwalletFactory;

    address payable soulwalletAddress;
    KeyStore keystoreContract;

    OpKnownStateRootWithHistory opKnownStateRootWithHistory;

    KeystoreProof keystoreProofContract;

    bytes32 private constant _TYPE_HASH_SET_KEY =
        keccak256("SetKey(bytes32 keyStoreSlot,uint256 nonce,bytes32 newSigner)");
    bytes32 private constant _TYPE_HASH_SET_GUARDIAN =
        keccak256("SetGuardian(bytes32 keyStoreSlot,uint256 nonce,bytes32 newGuardianHash)");
    bytes32 private constant _TYPE_HASH_SET_GUARDIAN_SAFE_PERIOD =
        keccak256("SetGuardianSafePeriod(bytes32 keyStoreSlot,uint256 nonce,uint64 newGuardianSafePeriod)");
    bytes32 private constant _TYPE_HASH_CANCEL_SET_GUARDIAN =
        keccak256("CancelSetGuardian(bytes32 keyStoreSlot,uint256 nonce)");
    bytes32 private constant _TYPE_HASH_CANCEL_SET_GUARDIAN_SAFE_PERIOD =
        keccak256("CancelSetGuardianSafePeriod(bytes32 keyStoreSlot,uint256 nonce)");
    bytes32 private constant _TYPE_HASH_SOCIAL_RECOVERY =
        keccak256("SocialRecovery(bytes32 keyStoreSlot,uint256 nonce,bytes32 newSigner)");

    bytes32 private constant _TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private DOMAIN_SEPARATOR;

    function run() public {
        // wallet signer info
        walletSingerPrivateKey = vm.envUint("WALLET_SIGNGER_PRIVATE_KEY");
        walletSigner = vm.addr(walletSingerPrivateKey);
        // guardian info
        guardianPrivateKey = vm.envUint("GUARDIAN_PRIVATE_KEY");
        guardianAddress = vm.addr(guardianPrivateKey);

        vm.startBroadcast(walletSingerPrivateKey);
        Network network = NetWorkLib.getNetwork();
        if (network == Network.Mainnet) {
            console.log("create wallet process on mainnet");
        } else if (network == Network.Goerli) {
            console.log("create wallet process on Goerli");
            changeKeyStoreKeyByGuardian();
            //     createWallet();
            // changeKeyStoreKeyByGuardian();
            // syncKeyStore();
            // getSlot();
        } else if (network == Network.Arbitrum) {
            console.log("create wallet process on Arbitrum");
        } else if (network == Network.Optimism) {
            console.log("create wallet process on Optimism");
            opSyncL1Block();
        } else if (network == Network.Anvil) {
            console.log("create wallet process on Anvil");
        } else if (network == Network.OptimismGoerli) {
            console.log("create wallet process on OptimismGoerli");
            // opSyncL1Block();
            // getSlot();
            // opKeystoreProof();
            // createWallet();
            syncKeyStore();
        } else if (network == Network.ArbitrumGoerli) {
            // syncKeyStore();
            // arbAcountProof();
            // arbKeystoreProof();
            createWallet();
        } else {
            console.log("create wallet process on testnet");
        }
    }

    function createWallet() private {
        bytes32 salt = bytes32(0);
        bytes[] memory modules = new bytes[](2);
        // security control module setup
        securityControlModuleAddress = loadEnvContract("SECURITY_CONTROL_MODULE_ADDRESS");
        modules[0] = abi.encodePacked(securityControlModuleAddress, abi.encode(uint64(2 days)));
        // keystore module setup
        keystoreModuleAddress = loadEnvContract("KEYSTORE_MODULE_ADDRESS");
        address[] memory guardians = new address[](1);
        guardians[0] = guardianAddress;
        bytes memory rawGuardian = abi.encode(guardians, guardianThreshold, 0);
        bytes32 initialGuardianHash = keccak256(rawGuardian);

        bytes memory keystoreModuleInitData =
            abi.encode(walletSigner.toBytes32(), initialGuardianHash, initialGuardianSafePeriod);
        modules[1] = abi.encodePacked(keystoreModuleAddress, keystoreModuleInitData);

        bytes[] memory plugins = new bytes[](0);
        bytes32[] memory owners = new bytes32[](1);
        owners[0] = walletSigner.toBytes32();

        defaultCallbackHandler = loadEnvContract("DEFAULT_CALLBACK_HANDLER_ADDRESS");
        bytes memory initializer = abi.encodeWithSignature(
            "initialize(bytes32[],address,bytes[],bytes[])", owners, defaultCallbackHandler, modules, plugins
        );
        soulwalletFactory = SoulWalletFactory(loadEnvContract("SOULWALLET_FACTORY_ADDRESS"));
        address cacluatedAddress = soulwalletFactory.getWalletAddress(initializer, salt);

        soulwalletAddress = payable(soulwalletFactory.createWallet(initializer, salt));
        require(cacluatedAddress == soulwalletAddress, "calculated address not match");
        console.log("wallet address: ", soulwalletAddress);
    }

    function getSlot() private returns (bytes32) {
        keystoreContract = KeyStore(loadEnvContract("KEYSTORE_ADDRESS"));
        address[] memory guardians = new address[](1);
        guardians[0] = guardianAddress;
        bytes memory rawGuardian = abi.encode(guardians, guardianThreshold, 0);
        bytes32 initialGuardianHash = keccak256(rawGuardian);
        address[] memory owners = new address[](1);
        owners[0] = walletSigner;
        bytes memory rawOwners = abi.encode(owners);
        bytes32 slot = keystoreContract.getSlot(keccak256(rawOwners), initialGuardianHash, initialGuardianSafePeriod);
        console.logBytes32(slot);
        return slot;
    }

    function changeKeyStoreKeyByGuardian() private {
        keystoreContract = KeyStore(loadEnvContract("KEYSTORE_ADDRESS"));

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                _TYPEHASH, keccak256(bytes("KeyStore")), keccak256(bytes("1")), block.chainid, address(keystoreContract)
            )
        );

        newWalletSingerPrivateKey = vm.envUint("WALLET_SIGNGER_NEW_PRIVATE_KEY");
        newWalletSigner = vm.addr(newWalletSingerPrivateKey);
        address[] memory guardians = new address[](1);
        guardians[0] = guardianAddress;
        bytes memory rawGuardian = abi.encode(guardians, guardianThreshold, 0);
        bytes32 initialGuardianHash = keccak256(rawGuardian);
        address[] memory owners = new address[](1);
        owners[0] = walletSigner;
        bytes memory rawOwners = abi.encode(owners);

        bytes32 slot = keystoreContract.getSlot(keccak256(rawOwners), initialGuardianHash, initialGuardianSafePeriod);

        uint256 nonce = keystoreContract.nonce(slot);

        address[] memory newOwners = new address[](1);
        newOwners[0] = newWalletSigner;
        bytes memory newRawOwners = abi.encode(newOwners);

        bytes32 structHash = keccak256(abi.encode(_TYPE_HASH_SOCIAL_RECOVERY, slot, nonce, keccak256(newRawOwners)));
        bytes32 typedDataHash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        bytes memory guardianSig = _signMsg(typedDataHash, guardianPrivateKey);

        keystoreContract.setKeyByGuardian(
            keccak256(rawOwners),
            initialGuardianHash,
            initialGuardianSafePeriod,
            keccak256(newRawOwners),
            newRawOwners,
            rawGuardian,
            abi.encodePacked(guardianSig)
        );

        IKeyStore.keyStoreInfo memory _keyStoreInfo = keystoreContract.getKeyStoreInfo(slot);
        require(_keyStoreInfo.key == keccak256(newRawOwners), "keyStoreInfo.key != newKey");
        console.log("changeKeyStoreKeyByGuardian success");
        console.log("newWalletSigner", newWalletSigner);
    }

    function syncKeyStore() private {
        bool beforeSync = SoulWallet(soulwalletAddress).isOwner(newWalletSigner.toBytes32());
        require(beforeSync == false, "before sync should not be new owner");
        KeyStoreModule(keystoreModuleAddress).syncL1Keystore(address(soulwalletAddress));

        bool afterSync = SoulWallet(soulwalletAddress).isOwner(newWalletSigner.toBytes32());
        require(afterSync == true, "after sync new owner not match");
    }

    function _signMsg(bytes32 messageHash, uint256 privateKey) private pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, messageHash);
        return abi.encodePacked(v, s, r);
    }

    function opSyncL1Block() private {
        opKnownStateRootWithHistory =
            OpKnownStateRootWithHistory(loadEnvContract("OP_KNOWN_STATEROOT_WITH_HISTORY_ADDRESS"));
        opKnownStateRootWithHistory.setBlockHash();
    }

    function opAcountProof() private {
        keystoreProofContract = KeystoreProof(loadEnvContract("OP_KEYSTORE_PROOF_ADDRESS"));
        bytes memory TEST_ACCOUNT_PROOF =
            hex"f90d33f90211a04929d9661086eff70820bd8a80d7c637ca03beb5ca778f9b21d42a7a196f1fd5a086ba934866f20ca2e97667fc714e51ff1f17e5c71e4812fcc786e77b660ca0f8a05be8b5d2537d127b7029af99848309c5683a467961606686578a6ecce2028ff5a0782ded982b2b582e507ddb9e70396c2ef204bffd86fb24f5738cff16a91b7e6ca04dbd564361909743571b15968b03e5871a5a8128817d6dc30247c455b32abe80a011459f96f20f50215b9325f80359dd8800482c3c7c3f1e2e7eede845807988e3a0a4808d3b901323c3c4f29dfba321c86cdb21ba34546674432c03da85e9a75d10a07ee24aa152360e40ac04a555df9437574bc36676e60f7fbf52e3b77976adc6fda05e7d5230df91422d9ae9b731586d1948d7ec05f3580e516aa89c6eaf9e3a836ba034dd6521de3ab3693874089204839d66c7c3c647052b56c4d2c330635bc3be9ba0e7b186487930511ea4f84dd12f30664cbed9331a677b92359ecf2a48325ddcd7a047838131d0d2725b61e6f6647e1616e3c36cbb4e09d922a74ba0c14073b8ed98a0564f85912794ed394dff6ad4f468b172f45d14ec1f3cecaf545f22fe710dd955a06683e8b30c109da2be898f4b0b8938c10e1f0aa2f5bf47167ba9a10c39de161da0d9b3f9317d194ad63176085852d2ecffb19c0f1b663ca72b411ce6d993f5a8ada015d2153774c69b27a7da855b73cdc1d4152dfce9c2217b49a5aaf76b95d20ad680f90211a0d400d14c9027ac674964e1a0bad817fed692202668de70144e0b2040709479c9a055772b63ad61d9feb3ffefe784abcf6b651cf8e7aedc8b82f6c5ea98fae65e04a043efd5023da026e51e293b6ba7e4a77725d9d1628a35d6057fb273cbb8891766a0a0772dbefd4f82758704ccc5121f213f1fd4e6044d0b5a0ad82804296c252979a054c93e2f7602609f0dcde2dd288ab1cbf152b885d997e5debbd6dbd5b3cbb67da05ce21334b1c4475d703f5ab119ca694b8cb98155a9fe6133fe364d16de21c234a001589e4b52539b9d3e868c0536aa4772b7d0f6bdb4821edb3d12a50cfd1101e1a010e25c148e5f45721873a074a440fd53fa736ad9a9e5c3fc473d311112fdb74ca0af59c40bb119bb86c88823ea9b79be918f33d63b2107b36bef5d69c0700e1f73a0a73b892ff9c6e4fed569f24eddf2392fcbe9ea0af4bdef95fe9ee82a8553df31a0e58ef52f9837c8ea9de2e6ded63b557eeb07c91703ed52845b99bfea52904786a04a57f934f21114b77a22ad9f4fbea710deb074f1c1a0369028dba23810c81cdba0c3d178cee57180f5618a8b18a598d6e8dd476a00d3a69b6210d714569512b5f1a0c2d3b312952f836ce3e6045c4faeeb5b7215282aa2924da77006edd7d9ee3f82a0f7c612f9e655b53a50d79b86cfbed8d9368c4dd73dea7eb28611640f923b21f9a04151918daaeec10d95bdccbc68c9afbc3bc7b2a85546d72c2b3e57f7bdf58e1580f90211a09f8a31385559b0e4f678a260406c8df82b099ba407a3c9b2694a400b8a2447c2a02d8d6404d74e1b85deaa800f3c69d68771b63bd5aae433b842aadf1d06296159a0942abdf5a77b1ff8066938c25b4af3436320dd7e1d172b9bda61b3d98ea3e5f3a0462753ff5aa2287fdf2b514410e770ad38e144aadeb9cb9e58a8320440030f48a022422603db70da0c0ead8616c73515f68bf1a3f091a9b964e628085bb30f4228a021d41ef2335f9de257dc4a86c648436609132c9801356a7427c1d8973495fee2a01d13e9b093508e561d5dc954f7e5ff3d1f2d0788f90e4335bc7bdcf003ea5188a097d54bca83568aca9255b6a7e775164fcd45f2f0d1e164b563b3337b8b8ac15ca0d4d67548414a750c2dad33f45115f4356aa5a8e7092ffeafd9c6a53134b6d9e2a0af32fa2023f9f9eeb75208f85dd01f1af5f4630238d99ffb2fd91a0574c41dd6a095e5bdfb494e0c952224a1854112bf6bccba1e470b16ed9619b4b5b8f9e5bd15a0d86101891f98a710fde4789c2fd639cdaeac0ac4da398ebc0529aee7e64487b7a0425737fc0bd2edcd04b7775abec20490579cb5088c56210bfc315bbceb969e35a06b66e68c2b83779b3c2f4d622fa19efa615089ad597e738a44cedaa940fe0b66a0e49343dbba4f02e44f1b122a16f52d0579ff8f388a95e0d5875d138776793a2da009805f8124195228970ac155b056b4058343d9be02f3e04eff8e4ed34b3d38bc80f90211a0dd9154ce72990a3c87ebc99d8012fa46f639258db1400a048f6f404f3c7a4d21a0a07e5efe708778f62d28f963dc7d4e5142ab39ab70eafa5551e04a0edc58da14a0b2c92ef8f7b0ec1c66811589c8e2580e5740413cda3e0698f479bac0ddabab07a0eef5442e33e3e1ee6a267cbda34ffcb0fc0ed6a7b35a645af43c77426f87d18fa0775f80c8f6537bc0b414afe8605bf0ac32e778a66e2fee9e505f0b0e2c1658baa080166df628dd5f27472dfb63fa12304134d7c3b662960dbc852930b57cffcd57a0e6ee64a01d8f4873baaa7c2effa35b1737be1c97191bf340649bb8be8ad26bc4a05328bb4e673fc91718f3561967f100683c723872767be527038144e14ff60be2a00bf03eb00ee6c0fb9b35236da515cf2f0376c0b6af4bd77db00a7f7680364870a0e8e4b7fa7748c4d663beff69faf59fcb59f7bb397bbf3b1c92807c31244aaab9a083b8a200d50fccd9cc0fc1eca110d46cb4ec71a4efea9bd8ca81528e1ead61d5a0a3b5f01738b4b6ec6a91a78078685ded1e0d4340a5d0e04fd83efd50d64b8efda0eecba3add808de792da0dc2dbce269159f13b74f756011d2c6df9edb59362b6fa04d7341ed75f3270dc4735216bc0c656b515b7ae52f0262b401a1264b02ffc806a0cd64ade7900692cb324c34bc9d375f9ea49e5e59691c7f84c9a8177f22b54df2a02a4a79d89c393c9faeac64e39ea3254d6be6e790af69486419b3f23beea95e6c80f90211a0e41bf64445596b40748c950da36c1c56ce0e34b1bd750cc2274a5b39d93d7111a039c0efe4ec9cff8ea4fef3392c2236fad2882e83f9314663b116c3d22820d3afa03e2e7e398fd69b3c1b85a502fa481b75c43bac12bea9079ff016a0287f2e30fba03680bbc8f49119c718ee0d9749333b9df21b282154fdaf4db71792e1eca1cad1a0e5a6d138b1b591bbc0c7466e90ebd44395d8f5a2123252e9c2a2af176708086aa0864a22d1e4f835d1d99e961622ab119f805c36b08aed8c18bd176fe11ba0f5d7a05bd1302fb5ca77508a661a26f330f9d53b6df46fe1dc8ef5feee98212e7f39e7a01e4bcab216b745b5b22b90cc4202802af1542bdc3d3d5496ae5561dbf478a271a01dd5d85cbea94c43e85e32acb27988fea20154547cee417eecd11e11e74de7aaa0841548e9f407a363fbd87c9df7bfdf0177c1e9418292cd69bb5278198c9c74f0a0db4e6d5f93951f7e063a8cfb90d430b20c1b608fefc4ba5f5cd184dd154a995ea0dbc5eef0e016d8e97b7c30dba2144a6b88b8355073340ebf2e9096405b3ccceda0fd8b6420f420fac93d47e8df12e0e49e6049926aff5f572b1b30136c9ceb96a8a0c7b4570dddd9e21c5f79ed2f83c595f5ed953c27688d5efbd3975f80cb27812ea0abdcd372e8d45d6acb51e8fc73bb61565ee70d4733ee09f52730b53b3a0dbaf8a0c012de4c7d36d90526072304789489bdc61f9b92ee5bf129afb19a145f53ac6d80f901f1a0e0a5ae46ea12586f6518c4daccb54c1ef2a07ac4da13e829a63a84acc5ce3539a07bd4587ab891775c30bb38c7b4846e3b58d5042ebd72b1e3e01e2e534e7c2b63a032b777447195b8491ddc9ed3446769f5f214f550ce2111c1cf543265f41aeaf5a0280e172c7580841dd0eb8209f051cd633a3a6b97729958affdfdfed2cb0f5ac2a0b222037efe6aec78fa8ed0807b7a5da7c4b4b167b36c9f25a91720cdd0615d55a03381fba8adf6286d3ba1fba0749977ddbf8f3aacf5faefd0e396ac5a43d2a894a0f93ba963bd12f2d3e3a56aa44be2b554fb1e2364964f60bf4fd0bc509fe4f658a04c6c807f43e9d65de71bd8b78428de19975fd1d9cf5fe40b40d7798bc5db4c2ba01ac0b585fb8b9a7d05063f901d38cfd02957f47fbb624c8a8092c933796bfd34a09b61d6604f3eafd86e896779e23867d4ee21f82d2bda3318fd4844f45ff11252a0233db780735e01b8550b779bdd6a491b2d525c5d959aec84d3877b29ad58ce05a08883c2c613c64769e215b64010f0ab2d37348b42995baa109fb129082d4c43aca03a2b568296f88d34d05babd35bd38c04625a121fac192b8e1a4f4f0da693d102a03d2292948a4a9172b7fd31eff517b3c7cc4218ef4bd111cabf8f3cfeee03d7fd80a0e1a3d53cf5a362472aad8629d8fdbe76e01ad23872b95af89fbc41e0ff82d23580f871a00af7fcd74735a55429e376044d6fa6d24a1990bb3a464b3d714a20f5ba75e7e780808080808080808080a07f992b1a0b5924409a1cd369b379b0c57059de89f1fe9b1a9bd36a9984cfd782808080a073854767028d4a70c0b533d0dbf9db4cb27ae1fd2c2908852f9cba52c37ca1a680f8669d378d5a240eab142c63aa541e84135302ed710e24edc09da0dc120966e3b846f8440180a0c424da7802c4ae39075dbaee5799595fd28ccb3f9709df59c3d1363d8be383e1a0867882272a050829439d92c1fc26f5a759404746428ee98e0079b660f98162c2";
        keystoreProofContract.proofKeystoreStorageRoot(
            hex"ded104e47ed0c60db0fda3b8395286420fb65e5686854ea627f9d5b60ca00600", TEST_ACCOUNT_PROOF
        );
    }

    function arbAcountProof() private {
        keystoreProofContract = KeystoreProof(loadEnvContract("ARB_KEYSTORE_PROOF_ADDRESS"));
        bytes memory TEST_ACCOUNT_PROOF =
            hex"f90d33f90211a053803e9d9a695a470ec0968ef6e55785be83829de66d74fdd19e9c892cdd46f4a096088de20781c436e922505f960c1735d3e171d916c6b9225782509f26806bbfa064726896ded62655e3194c5daca6eb7599dd7619afaf92a65fa04dab85318a94a00261aaeae801926463e0ca31a13a1409539bc6dbabead8df050432d2eb21ffcfa0517bbe63a49d914af54498d899fd95c23b4284af8de709c9b4a5e96cf4748a1da05c9ea5a79de5160e5d9d9cffaa56a12c9059f8c8a8095cda986602e669d12c70a0b511d11dc8b8a90407823c76523b4e7b582b497fea898d9a70ae491820f8ba28a02112ef41d205095790bdbfb2bf49d8c5f74cebe3bc609ce517754d3ab65d588ca09a115de4eef54feb38e40d9f7019cc7996114264ccc87ea4e0df6734ae0eec47a0b34098623f3f79370214147d8c4e7d48b2461bea563ad23bbb82189b893c1e48a00bace14828d738aa4fd4d1a4b59ee5f27634ac677e33c319cddb03f208262b72a01f6066857371543856b666cdd3feba5f8539b054907bc583fb259bdc8bbd5cf9a036cf46281a341a8a6a9e81b4b7c28db61a5f21f56b31a797c704994e75fb24c8a0827346cb0c6ef84d20550bead63cc91fdfdf9a396b75232a1d6f7e97704333cfa07b84897c2006a09b2579d76e88465fd8dcd950cb652ad0c3a54824fca0be1967a0e9dcf4e5807d2d0d6d9ea5052b4f92c13bbdf86dc4e717bb7c94be6895745faf80f90211a0d0a3fb6c8426104c600885bd9b19db0eb1ee187de67597a46561b0c1edf9927aa0ab216ef0251bbd4ad89ee4090724454c0fd96ccb044af7274212442d8916aec5a04967cacfbb212d24cf204ff4378763cd2beffb8239d8725b133734573f06603ba0b9c05cb3929a615b343020e76eaba8cf055e38cabc339a54c5fced9f5e267b1ea0a359d35b1accb445e09a00ed73013ff5727392aee473899c48ecdf9ff9f20416a0867c044483facd64dda901176c7b0306251dd5605c3969c2c2712de6b14a79fba080a4a7bc48dc8fda121b5fdfff1e6b7adb85000dce6294da1098477ef141bb19a088fd967a7a5830c0d9da81d5f839dfcaccefb9e0b1f8538d31e855262b85917aa0537eadc05b268c7ea49210cd983a147354274639434d0b37f47360ac716f70dca06f9b990712b5cbe732282e87d0d161e65419e592010d1782f318d6d41352f69ba082c281a2b90016ce1b09a472d56840862ca33bc6de76d57e6926d4f586e2e5eaa0e5f5b63990986d642c5173ed9bce52f9986ddc933ce8a1fb3bd30b65936af168a05e719f1377cf3261110c46b8c5c722a46023245eee8263807c093eae3a77b95da0f7fe730fe463d427737661b5cf2843ce89010f305b767dce95d4a3f5544a550ea004dc45d68e062bdc18452267d36799d87b1b620273b6f8f8434c0f06d0f0b0a9a030637902d848d595e1a9e6e35e598bdfd9a4cdc2d7487ff9d451bbeafad60bf980f90211a09cd40b513bc4adf5183c13e62da8ac8ab7ea1ae398cc7440d4286037cf22af2ea0545b4198cdc01bd2fbed4587c05b28945dc686c93dbf20f16c9adb2266f5326aa0135413fe296db4bf1fdc2269e051ba9fce78f22cdb36b6d664d842aa22449688a05a35c8281f747208c9fed891ef628931558109529975aa9c46a9dc0df7e2b1b4a0c30837323f0e42fb18b35cab20a1bab48ff704935592fb4c7ac2f69d29dcfa06a0400743630bee560c8c5abc6ee42c5b372d984165bc958e124323b4943572a0dda028d65bd8441ce112f9f346b3eea5bdc6684b52f266971a0d3b11218495946061a065a0df289403a96cfa3ba7824185dc9960414f6669519b5c383a4262d67e5b41a0bb6c8b8325a88bafb5968d33400d6fc463ea155b5b51fe332ed2e227e1357ce2a025b83e5720e422d6ba52572d225161d44d662464949ef999c27ec545a2b1c49fa042e41fe1233b82149e825e440de54a802d6a8db493b6df43150512572222b1daa0314cf7302e3c9af7bf894c3f569f361d0b6d972fdbd39ca9b522e61e0dd6a3b8a0b636ff51cad6cf3ad324506ecd41fad332d19cb17bd92ec0f4e417139ce7fa9ba0af330e8a622e0565856dd1ae774ffcd889e2c6334b2b274a530df46fc237e71ca02251b6379a5db3d91f8211d8c17bf405a1eab8888b4c758f0e7b232343aee15ca0a07b2dc4d2919e26766fe6470196c1fd90f4154b828ecd7c9d1482ad61e7506680f90211a02df2281c9f75d0b7bd5ab16cdf089eed114edee92420b27a88f44cb338f1e85fa02f35e4f3bf1f9d8d579805ce909db97771cf4bfff544f66edc02888ccdeee425a0cad89696ce01429ee07eeb504d36bf80e523ff2960cf9f639ac0c8aec25df23aa0eab69f9236ccac55b9825b6c680168873a930c807509390bab965a4ae7b837d8a0f4065fd45b3ffca2bd7dc377e3b5a64ade858df811d593a8a6951fad34188140a0dbb7f8081430fb21db781e393dc22bee0590476882a3fd295f3a9fdbe37ae6a3a0d1d4f9b5786f2ef7464cc54db3c746771a4f608892b3b7ba9145d3ced6a44629a09f0542fb27fa245dc51e50d3069042bc0774b713eebb3f260995fe31d9f284dea06cef7d3e8586ee17a4a654189a88a1d1d41af67a98a5fd6f5a2830d50fe1ec15a0d78a0c8c4ce0560640104bd915bd23ba2b9c476a5503dd427d8cb9ef87ec80d4a0aee1a2be9dabc7ee6091d19d19a31c6121f84c0fb8e0162a271a9d5bc1d45a0ba0f1be237618858210b7739ea49415361ba0ea4cbf573050cc622911bc809a803ea01588e319d699ac5c32c5f4d02fdfd8c157706df24fa40ab78cac50785ea18697a028e77b9179a96f0177e547c383561e9eedc69beb56cd3a978734ae407146498da0103d9e8f85143f2c5a9d49f9effb3080edd80cf57f4089c7c430ddbd3ad3d786a0aa892c5d83ddce56e941c6c2ae3c2ae9ca8cd53ec60985dfa372e0e5326c43c880f90211a0e41bf64445596b40748c950da36c1c56ce0e34b1bd750cc2274a5b39d93d7111a081d3eac911730120b2da2e9f8d229b30be5eafeba654fd2035a713454d8fbb8fa03e2e7e398fd69b3c1b85a502fa481b75c43bac12bea9079ff016a0287f2e30fba03680bbc8f49119c718ee0d9749333b9df21b282154fdaf4db71792e1eca1cad1a0e5a6d138b1b591bbc0c7466e90ebd44395d8f5a2123252e9c2a2af176708086aa0864a22d1e4f835d1d99e961622ab119f805c36b08aed8c18bd176fe11ba0f5d7a05bd1302fb5ca77508a661a26f330f9d53b6df46fe1dc8ef5feee98212e7f39e7a01e4bcab216b745b5b22b90cc4202802af1542bdc3d3d5496ae5561dbf478a271a01dd5d85cbea94c43e85e32acb27988fea20154547cee417eecd11e11e74de7aaa0210784ee98a443c5647317d649eaf2b63619deeca2f098e24901485fe1de9d78a0db4e6d5f93951f7e063a8cfb90d430b20c1b608fefc4ba5f5cd184dd154a995ea0a558b2a52b703d615319c7944e58a961d1a593dc795f82466a69d10f1b8872c3a0fd8b6420f420fac93d47e8df12e0e49e6049926aff5f572b1b30136c9ceb96a8a0c7b4570dddd9e21c5f79ed2f83c595f5ed953c27688d5efbd3975f80cb27812ea0abdcd372e8d45d6acb51e8fc73bb61565ee70d4733ee09f52730b53b3a0dbaf8a0da67eda97aae78b0a548379bfe6f850f2af4f7bdec9db13956fb9f44b14fd23180f901f1a010d08739e83b36b6961412d5cde580c058032e6a44126bbf25435a57554e12f1a07bd4587ab891775c30bb38c7b4846e3b58d5042ebd72b1e3e01e2e534e7c2b63a032b777447195b8491ddc9ed3446769f5f214f550ce2111c1cf543265f41aeaf5a0280e172c7580841dd0eb8209f051cd633a3a6b97729958affdfdfed2cb0f5ac2a0b222037efe6aec78fa8ed0807b7a5da7c4b4b167b36c9f25a91720cdd0615d55a03381fba8adf6286d3ba1fba0749977ddbf8f3aacf5faefd0e396ac5a43d2a894a0f93ba963bd12f2d3e3a56aa44be2b554fb1e2364964f60bf4fd0bc509fe4f658a04c6c807f43e9d65de71bd8b78428de19975fd1d9cf5fe40b40d7798bc5db4c2ba01ac0b585fb8b9a7d05063f901d38cfd02957f47fbb624c8a8092c933796bfd34a09b61d6604f3eafd86e896779e23867d4ee21f82d2bda3318fd4844f45ff11252a0233db780735e01b8550b779bdd6a491b2d525c5d959aec84d3877b29ad58ce05a08883c2c613c64769e215b64010f0ab2d37348b42995baa109fb129082d4c43aca03a2b568296f88d34d05babd35bd38c04625a121fac192b8e1a4f4f0da693d102a03d2292948a4a9172b7fd31eff517b3c7cc4218ef4bd111cabf8f3cfeee03d7fd80a0e1a3d53cf5a362472aad8629d8fdbe76e01ad23872b95af89fbc41e0ff82d23580f871a00af7fcd74735a55429e376044d6fa6d24a1990bb3a464b3d714a20f5ba75e7e780808080808080808080a07f992b1a0b5924409a1cd369b379b0c57059de89f1fe9b1a9bd36a9984cfd782808080a0b6b294a373b22f8f327ff8d241743884bab3c8692bbccc303744a97e99a7488780f8669d378d5a240eab142c63aa541e84135302ed710e24edc09da0dc120966e3b846f8440180a0550148708cbc5f574beaa196a007667b693d9862de5b8edf1cfc7860aab9a736a0867882272a050829439d92c1fc26f5a759404746428ee98e0079b660f98162c2";
        keystoreProofContract.proofKeystoreStorageRoot(
            hex"ab5981a1bcec73ae9dd1fb096640e8f7f52946b045fabe538542af07123ef3f2", TEST_ACCOUNT_PROOF
        );
    }

    function opKeystoreProof() private {
        keystoreProofContract = KeystoreProof(loadEnvContract("OP_KEYSTORE_PROOF_ADDRESS"));
        address[] memory owners = new address[](1);
        owners[0] = newWalletSigner;
        bytes memory rawOwners = abi.encode(0x598991c9D726cBac7EB023Ca974fe6e7e7a57Ce8);

        keystoreProofContract.proofL1Keystore(
            0x30c04d81b7c8fcca55a64a5ffbf2ced4517744fd2b68928b8080a96465ec9f6f,
            0xded104e47ed0c60db0fda3b8395286420fb65e5686854ea627f9d5b60ca00600,
            keccak256(rawOwners),
            rawOwners,
            hex"f8cbf8918080808080a06ed5c01b2444c8373690836388d91d9227b9999821522c6c66b2565fb246efb9808080a0be05134e40d2fc74e8e4e62b8766ffa4b44f402501c8b29c59c3e929b64162dc8080a03d0324ec4704a293545dbccab4fe7096cf56f96f75ec163131d43fe487b2efcb80a0aeeeee702f51c895c5c005029966cc66cf16052d7930446e36563dcde2f1a9b38080f7a03f025a1553395601db3a10ebbbbbb1e6e2a959fa5964eaa63a45a14e3dcb994b9594598991c9d726cbac7eb023ca974fe6e7e7a57ce8"
        );
    }

    function arbKeystoreProof() private {
        keystoreProofContract = KeystoreProof(loadEnvContract("ARB_KEYSTORE_PROOF_ADDRESS"));
        address[] memory owners = new address[](1);
        owners[0] = newWalletSigner;
        bytes memory rawOwners = abi.encode(0x598991c9D726cBac7EB023Ca974fe6e7e7a57Ce8);
        keystoreProofContract.proofL1Keystore(
            0x30c04d81b7c8fcca55a64a5ffbf2ced4517744fd2b68928b8080a96465ec9f6f,
            0xab5981a1bcec73ae9dd1fb096640e8f7f52946b045fabe538542af07123ef3f2,
            keccak256(rawOwners),
            rawOwners,
            hex"f8cbf8918080808080a02155da169730f5d618ef5c813543c49d66415688a7d0f7c81dd7237bce87fb9e808080a0be05134e40d2fc74e8e4e62b8766ffa4b44f402501c8b29c59c3e929b64162dc8080a060d8ed27c8022702fc0cadf1ce5d49a59371442e5f5ab15b008fdcd5a963418880a0aeeeee702f51c895c5c005029966cc66cf16052d7930446e36563dcde2f1a9b38080f7a03f025a1553395601db3a10ebbbbbb1e6e2a959fa5964eaa63a45a14e3dcb994b959468d9fb9427175af4d3c65fc9754c7383c70277bc"
        );
    }

    function loadEnvContract(string memory label) private view returns (address) {
        address contractAddress = vm.envAddress(label);
        require(contractAddress != address(0), string(abi.encodePacked(label, " not provided")));
        require(contractAddress.code.length > 0, string(abi.encodePacked(label, " needs be deployed")));
        return contractAddress;
    }
}
