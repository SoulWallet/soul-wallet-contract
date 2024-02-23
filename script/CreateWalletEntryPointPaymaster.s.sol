// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@source/factory/SoulWalletFactory.sol";
import "@source/SoulWallet.sol";
import "@source/keystore/L1/KeyStore.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {UserOperationLib} from "@account-abstraction/contracts/core/UserOperationLib.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@source/libraries/TypeConversion.sol";
import {Solenv} from "@solenv/Solenv.sol";
import {Execution} from "@soulwallet-core/contracts/interface/IStandardExecutor.sol";
import {UserOperationHelper} from "@soulwallet-core/test/dev/userOperationHelper.sol";

contract CreateWalletEntryPointPaymaster is Script {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    using TypeConversion for address;
    using UserOperationLib for PackedUserOperation;

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
    EntryPoint public entryPoint = EntryPoint(payable(0x0000000071727De22E5E9d8BAf0edAc6f37da032));

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
        bytes32 salt = bytes32(uint256(12));
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

        address payToken = loadEnvContract("PAYTOKEN_ADDRESS");
        address paymaster = loadEnvContract("Paymaster");

        Execution[] memory executions = new Execution[](1);
        executions[0].target = address(payToken);
        executions[0].value = 0;
        executions[0].data = abi.encodeWithSignature("approve(address,uint256)", address(paymaster), 10000e6);
        bytes memory callData = abi.encodeWithSignature("executeBatch((address,uint256,bytes)[])", executions);
        bytes memory paymasterAndData = abi.encodePacked(
            abi.encodePacked(address(paymaster), uint128(400000), uint128(400000)),
            abi.encode(address(payToken), uint256(10000e6))
        );

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);

        PackedUserOperation memory userOperation = UserOperationHelper.newUserOp({
            sender: cacluatedAddress,
            nonce: 0,
            initCode: initCode,
            callData: callData,
            callGasLimit: 5000000,
            verificationGasLimit: 1000000,
            preVerificationGas: 500000,
            maxFeePerGas: 10000,
            maxPriorityFeePerGas: 10000,
            paymasterAndData: paymasterAndData
        });
        userOperation.signature = signUserOp(userOperation, walletSingerPrivateKey, soulWalletDefaultValidator);

        ops[0] = userOperation;

        uint256 bundlerSinger = vm.envUint("WALLET_SIGNGER_PRIVATE_KEY");
        console.log("bundelr address ", vm.addr(bundlerSinger));
        vm.startBroadcast(bundlerSinger);
        console.log("entryPoint", address(entryPoint));
        console.log("beneficiary ", vm.addr(bundlerSinger));
        entryPoint.handleOps(ops, payable(vm.addr(bundlerSinger)));
    }

    function signUserOp(PackedUserOperation memory op, uint256 _key, address _validator)
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
