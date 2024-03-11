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
import {UserOperationHelper} from "@soulwallet-core/test/dev/userOperationHelper.sol";
import {IStandardExecutor} from "@soulwallet-core/contracts/interface/IStandardExecutor.sol";
import {Execution} from "@soulwallet-core/contracts/interface/IStandardExecutor.sol";

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
    EntryPoint public entryPoint = EntryPoint(payable(0x0000000071727De22E5E9d8BAf0edAc6f37da032));

    function run() public {
        Solenv.config(".env_backend");
        // wallet signer info
        walletSingerPrivateKey = vm.envUint("WALLET_SIGNGER_NEW_PRIVATE_KEY");
        soulWalletDefaultValidator = loadEnvContract("SoulWalletDefaultValidator");
        walletSigner = vm.addr(walletSingerPrivateKey);

        // guardian info
        guardianPrivateKey = vm.envUint("GUARDIAN_PRIVATE_KEY");
        guardianAddress = vm.addr(guardianPrivateKey);

        createWallet();
    }

    function createWallet() private {
        vm.startBroadcast(walletSingerPrivateKey);
        bytes32 salt = bytes32(uint256(3));
        bytes[] memory modules = new bytes[](0);

        bytes32[] memory owners = new bytes32[](1);
        owners[0] = walletSigner.toBytes32();

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
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);

        address aaveUsdcAutomationAddress = loadEnvContract("SOUL_WALLET_AAVE_USDC_AUTOMATION_SEPOLIA");
        bytes memory approveData =
            abi.encodeWithSignature("approve(address,uint256)", aaveUsdcAutomationAddress, 10000 ether);
        address usdcAddress = loadEnvContract("USDC_SEPOLIA");

        PackedUserOperation memory userOperation = UserOperationHelper.newUserOp({
            sender: cacluatedAddress,
            nonce: 0,
            initCode: initCode,
            callData: abi.encodeWithSelector(IStandardExecutor.execute.selector, usdcAddress, 0, approveData),
            callGasLimit: 900000,
            verificationGasLimit: 1000000,
            preVerificationGas: 300000,
            maxFeePerGas: 10000,
            maxPriorityFeePerGas: 10000,
            paymasterAndData: hex""
        });
        userOperation.signature = signUserOp(userOperation, walletSingerPrivateKey, soulWalletDefaultValidator);
        logUserOp(userOperation);

        ops[0] = userOperation;

        entryPoint.handleOps(ops, payable(walletSigner));
    }

    function withDrawAndTransfer() private {
        vm.startBroadcast(walletSingerPrivateKey);
        Execution[] memory executions = new Execution[](2);
        executions[0].target = address(0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951);
        executions[0].value = 0;
        executions[0].data = abi.encodeWithSignature(
            "withdraw(address,uint256,address)",
            address(0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8),
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            address(0x7aD6443c55A1eD75b63b9Cce601E1591F20B42f3)
        );
        executions[1].target = address(0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8);
        executions[1].value = 0;
        executions[1].data = abi.encodeWithSignature(
            "transfer(address,uint256)", address(0xf4bF967767Cc55dd73EF19E1DA7b58A1B39f0782), 1000e6
        );

        bytes memory callData = abi.encodeWithSignature("executeBatch((address,uint256,bytes)[])", executions);

        PackedUserOperation memory userOperation = UserOperationHelper.newUserOp({
            sender: 0x7aD6443c55A1eD75b63b9Cce601E1591F20B42f3,
            nonce: 4,
            initCode: hex"",
            callData: callData,
            callGasLimit: 1900000,
            verificationGasLimit: 1000000,
            preVerificationGas: 300000,
            maxFeePerGas: 10000,
            maxPriorityFeePerGas: 10000,
            paymasterAndData: hex""
        });
        userOperation.signature = signUserOp(userOperation, walletSingerPrivateKey, soulWalletDefaultValidator);
        logUserOp(userOperation);
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);

        ops[0] = userOperation;

        entryPoint.handleOps(ops, payable(walletSigner));
    }

    function logUserOp(PackedUserOperation memory op) private view {
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
