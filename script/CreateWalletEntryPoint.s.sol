// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@source/factory/SoulWalletFactory.sol";
import "@source/keystore/L1/KeyStore.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@source/libraries/TypeConversion.sol";
import {Solenv} from "@solenv/Solenv.sol";

contract CreateWalletEntryPoint is Script {
    using ECDSA for bytes32;
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
    address soulWalletDefaultValidator;

    SoulWalletFactory soulwalletFactory;

    address payable soulwalletAddress;
    KeyStore keystoreContract;

    bytes emptyBytes;
    EntryPoint public entryPoint = EntryPoint(payable(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789));

    function run() public {
        Solenv.config(".env_backend");
        // wallet signer info
        walletSingerPrivateKey = vm.envUint("WALLET_SIGNGER_NEW_PRIVATE_KEY");
        walletSigner = vm.addr(walletSingerPrivateKey);

        // guardian info
        guardianPrivateKey = vm.envUint("GUARDIAN_PRIVATE_KEY");
        guardianAddress = vm.addr(guardianPrivateKey);

        createWallet();
    }

    function createWallet() private {
        vm.startBroadcast(walletSingerPrivateKey);
        bytes32 salt = bytes32(uint256(3));
        bytes[] memory modules = new bytes[](2);
        // security control module setup
        securityControlModuleAddress = loadEnvContract("SecurityControlModule");
        soulWalletDefaultValidator = loadEnvContract("SoulWalletDefaultValidator");
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

        bytes memory soulWalletFactoryCall = abi.encodeWithSignature("createWallet(bytes,bytes32)", initializer, salt);
        bytes memory initCode = abi.encodePacked(address(soulwalletFactory), soulWalletFactoryCall);
        console.log("cacluatedAddress", cacluatedAddress);

        entryPoint.depositTo{value: 0.005 ether}(cacluatedAddress);
        UserOperation[] memory ops = new UserOperation[](1);

        UserOperation memory userOperation = UserOperation({
            sender: cacluatedAddress,
            nonce: 0,
            initCode: initCode,
            callData: hex"",
            callGasLimit: 900000,
            verificationGasLimit: 1000000,
            preVerificationGas: 300000,
            maxFeePerGas: 10000,
            maxPriorityFeePerGas: 10000,
            paymasterAndData: hex"",
            signature: hex""
        });
        userOperation.signature = signUserOp(userOperation, walletSingerPrivateKey, soulWalletDefaultValidator);
        logUserOp(userOperation);

        ops[0] = userOperation;

        entryPoint.handleOps(ops, payable(walletSigner));
    }

    function logUserOp(UserOperation memory op) private view {
        console.log("sender: ", op.sender);
        console.log("nonce: ", op.nonce);
        console.log("initCode: ");
        console.logBytes(op.initCode);
        console.log("callData: ");
        console.logBytes(op.callData);
        console.log("paymasterAndData: ");
        console.logBytes(op.paymasterAndData);
        console.log("signature: ");
        console.logBytes(op.signature);
    }

    function signUserOp(UserOperation memory op, uint256 _key, address _validator)
        public
        view
        returns (bytes memory signature)
    {
        bytes32 hash = entryPoint.getUserOpHash(op);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_key, hash.toEthSignedMessageHash());
        bytes memory opSig;
        bytes memory signatureData = abi.encodePacked(r, s, v);
        uint8 signType = 0;
        bytes4 signatureLength = bytes4(uint32(1 + signatureData.length));
        opSig = abi.encodePacked(_validator, signatureLength, signType, signatureData);
        signature = opSig;
    }

    function loadEnvContract(string memory label) private view returns (address) {
        address contractAddress = vm.envAddress(label);
        require(contractAddress != address(0), string(abi.encodePacked(label, " not provided")));
        require(contractAddress.code.length > 0, string(abi.encodePacked(label, " needs be deployed")));
        return contractAddress;
    }
}
