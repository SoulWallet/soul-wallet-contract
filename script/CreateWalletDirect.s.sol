// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@source/factory/SoulWalletFactory.sol";
import "@source/keystore/L1/KeyStore.sol";
import "./DeployHelper.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@source/modules/keystore/optimism/OpMerkleRootHistory.sol";
import "@source/modules/keystore/KeyStoreMerkleProof.sol";
import {NetWorkLib} from "./DeployHelper.sol";
import "@source/libraries/TypeConversion.sol";
import {Solenv} from "@solenv/Solenv.sol";

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
    KeyStore keyStoreContract;

    OpMerkleRootHistory opMerkleRootHistory;

    KeyStoreMerkleProof keyStoreMerkleProof;

    bytes32 private constant _TYPE_HASH_SET_KEY =
        keccak256("SetKey(bytes32 keyStoreSlot,uint256 nonce,bytes32 newSigner)");
    bytes32 private constant _TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 private DOMAIN_SEPARATOR;

    function run() public {
        Solenv.config(".env_backend");
        // wallet signer info
        walletSingerPrivateKey = vm.envUint("WALLET_SIGNGER_PRIVATE_KEY");
        walletSigner = vm.addr(walletSingerPrivateKey);
        // guardian info
        guardianPrivateKey = vm.envUint("GUARDIAN_PRIVATE_KEY");
        guardianAddress = vm.addr(guardianPrivateKey);

        vm.startBroadcast(walletSingerPrivateKey);
        string memory networkName = NetWorkLib.getNetworkName();
        console.log("create wallet on ", networkName);
        createWallet();
    }

    function createWallet() private {
        bytes32 salt = bytes32(0);
        bytes[] memory modules = new bytes[](2);
        // security control module setup
        securityControlModuleAddress = loadEnvContract("SecurityControlModule");
        modules[0] = abi.encodePacked(securityControlModuleAddress, abi.encode(uint64(2 days)));
        // keystore module setup
        keystoreModuleAddress = loadEnvContract("KeyStoreModuleProxy");
        address[] memory guardians = new address[](1);
        guardians[0] = guardianAddress;
        bytes memory rawGuardian = abi.encode(guardians, guardianThreshold, 0);
        bytes32 initialGuardianHash = keccak256(rawGuardian);
        bytes32[] memory owners = new bytes32[](1);
        owners[0] = walletSigner.toBytes32();

        bytes memory keystoreModuleInitData =
            abi.encode(keccak256(abi.encode(owners)), initialGuardianHash, initialGuardianSafePeriod);

        modules[1] = abi.encodePacked(keystoreModuleAddress, keystoreModuleInitData);

        bytes[] memory hooks = new bytes[](0);

        defaultCallbackHandler = loadEnvContract("DefaultCallbackHandler");
        bytes memory initializer = abi.encodeWithSignature(
            "initialize(bytes32[],address,bytes[],bytes[])", owners, defaultCallbackHandler, modules, hooks
        );
        soulwalletFactory = SoulWalletFactory(loadEnvContract("SoulwalletFactory"));
        address cacluatedAddress = soulwalletFactory.getWalletAddress(initializer, salt);

        soulwalletAddress = payable(soulwalletFactory.createWallet(initializer, salt));
        require(cacluatedAddress == soulwalletAddress, "calculated address not match");
        console.log("wallet address: ", soulwalletAddress);
    }

    function changeKeyStoreOwner() private {
        address keyStoreContractAddr = loadEnvContract("KeyStore");
        keyStoreContract = KeyStore(keyStoreContractAddr);

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                _TYPEHASH, keccak256(bytes("KeyStore")), keccak256(bytes("1")), block.chainid, address(keyStoreContract)
            )
        );
        bytes[] memory modules = new bytes[](2);
        // security control module setup
        securityControlModuleAddress = loadEnvContract("SecurityControlModule");
        modules[0] = abi.encodePacked(securityControlModuleAddress, abi.encode(uint64(2 days)));
        // keystore module setup
        keystoreModuleAddress = loadEnvContract("KeyStoreModuleProxy");
        address[] memory guardians = new address[](1);
        guardians[0] = guardianAddress;
        bytes memory rawGuardian = abi.encode(guardians, guardianThreshold, 0);
        bytes32 initialGuardianHash = keccak256(rawGuardian);
        bytes32[] memory owners = new bytes32[](1);
        owners[0] = walletSigner.toBytes32();

        bytes32 slot =
            keyStoreContract.getSlot(keccak256(abi.encode(owners)), initialGuardianHash, initialGuardianSafePeriod);

        bytes32[] memory newOwners = new bytes32[](2);
        newOwners[0] = walletSigner.toBytes32();
        newOwners[1] = guardianAddress.toBytes32();
        bytes32 initialKey_new_1 = keccak256(abi.encode(newOwners));
        uint256 nonce = keyStoreContract.nonce(slot);
        bytes32 structHash = keccak256(abi.encode(_TYPE_HASH_SET_KEY, slot, nonce, initialKey_new_1));
        bytes32 typedDataHash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(walletSingerPrivateKey, typedDataHash);

        bytes memory keySignature = abi.encodePacked(r, s, v);
        uint8 signType = 0;
        bytes memory validatorSignature = abi.encodePacked(signType, keySignature);
        keyStoreContract.setKeyByOwner(
            keccak256(abi.encode(owners)),
            initialGuardianHash,
            initialGuardianSafePeriod,
            abi.encode(newOwners),
            abi.encode(owners),
            validatorSignature
        );
    }

    function opMerkleProof() private {
        address keyStoreMerkleProofAddr = loadEnvContract("OpKeyStoreMerkleProof");
        keyStoreMerkleProof = KeyStoreMerkleProof(keyStoreMerkleProofAddr);
        bytes32[] memory zeros = new bytes32[](32);
        for (uint256 height = 0; height < 32 - 1; height++) {
            zeros[height + 1] = keccak256(abi.encodePacked(zeros[height], zeros[height]));
        }
        bytes32[] memory proofs = new bytes32[](32);
        for (uint256 i = 0; i < 32; i++) {
            proofs[i] = zeros[i];
        }

        bytes32[] memory newOwners = new bytes32[](2);
        newOwners[0] = walletSigner.toBytes32();
        newOwners[1] = guardianAddress.toBytes32();
        bytes32 initialKey_new_1 = keccak256(abi.encode(newOwners));

        keyStoreMerkleProof.proveKeyStoreData(
            hex"09DAD8B126439E69C798745D802291BD1E23A35E6D5DA810D0EFBA60D9CDFF42",
            hex"b601463e4e206436c303c3f22c03c360bf8af09c0558c755119500d884b5f7d2",
            initialKey_new_1,
            abi.encode(newOwners),
            5007550,
            0,
            proofs
        );
    }

    function arbMerkleProof() private {
        address keyStoreMerkleProofAddr = loadEnvContract("ArbKeyStoreMerkleProof");
        keyStoreMerkleProof = KeyStoreMerkleProof(keyStoreMerkleProofAddr);
        bytes32[] memory zeros = new bytes32[](32);
        for (uint256 height = 0; height < 32 - 1; height++) {
            zeros[height + 1] = keccak256(abi.encodePacked(zeros[height], zeros[height]));
        }
        bytes32[] memory proofs = new bytes32[](32);
        for (uint256 i = 0; i < 32; i++) {
            proofs[i] = zeros[i];
        }

        bytes32[] memory newOwners = new bytes32[](2);
        newOwners[0] = walletSigner.toBytes32();
        newOwners[1] = guardianAddress.toBytes32();
        bytes32 initialKey_new_1 = keccak256(abi.encode(newOwners));

        keyStoreMerkleProof.proveKeyStoreData(
            hex"09DAD8B126439E69C798745D802291BD1E23A35E6D5DA810D0EFBA60D9CDFF42",
            hex"b601463e4e206436c303c3f22c03c360bf8af09c0558c755119500d884b5f7d2",
            initialKey_new_1,
            abi.encode(newOwners),
            5007550,
            0,
            proofs
        );
    }

    function loadEnvContract(string memory label) private view returns (address) {
        address contractAddress = vm.envAddress(label);
        require(contractAddress != address(0), string(abi.encodePacked(label, " not provided")));
        require(contractAddress.code.length > 0, string(abi.encodePacked(label, " needs be deployed")));
        return contractAddress;
    }
}
