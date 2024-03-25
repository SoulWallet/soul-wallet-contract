// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {ISoulWallet} from "@source/interfaces/ISoulWallet.sol";
import "@source/validator/SoulWalletDefaultValidator.sol";
import {SoulWalletFactory} from "@source/factory/SoulWalletFactory.sol";
import "@source/abstract/DefaultCallbackHandler.sol";
import "@source/libraries/TypeConversion.sol";
import {SoulWalletLogicInstence} from "../base/SoulWalletLogicInstence.sol";
import {UserOpHelper} from "../../helper/UserOpHelper.t.sol";
import {Bundler} from "../../helper/Bundler.t.sol";
import {UserOperationHelper} from "@soulwallet-core/test/dev/userOperationHelper.sol";

contract DeployProtocolTest is Test, UserOpHelper {
    using TypeConversion for address;

    SoulWalletDefaultValidator public soulWalletDefaultValidator;
    SoulWalletLogicInstence public soulWalletLogicInstence;
    SoulWalletFactory public soulWalletFactory;
    Bundler public bundler;

    function setUp() public {
        entryPoint = new EntryPoint();
        soulWalletDefaultValidator = new SoulWalletDefaultValidator();
        soulWalletLogicInstence = new SoulWalletLogicInstence(address(entryPoint), address(soulWalletDefaultValidator));
        address logic = address(soulWalletLogicInstence.soulWalletLogic());

        soulWalletFactory = new SoulWalletFactory(logic, address(entryPoint), address(this));
        require(soulWalletFactory._WALLETIMPL() == logic, "logic address not match");

        bundler = new Bundler();
    }

    function test_Deploy() public {
        address sender;
        uint256 nonce;
        bytes memory initCode;
        bytes memory callData;
        uint256 callGasLimit = 10000000;
        uint256 verificationGasLimit;
        uint256 preVerificationGas;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        bytes memory paymasterAndData;

        (address walletOwner, uint256 walletOwnerPrivateKey) = makeAddrAndKey("walletOwner");
        {
            nonce = 0;

            bytes[] memory modules = new bytes[](0);
            bytes[] memory hooks = new bytes[](0);

            bytes32 salt = bytes32(0);

            DefaultCallbackHandler defaultCallbackHandler = new DefaultCallbackHandler();
            bytes32[] memory owners = new bytes32[](1);
            owners[0] = walletOwner.toBytes32();
            bytes memory initializer = abi.encodeWithSignature(
                "initialize(bytes32[],address,bytes[],bytes[])", owners, defaultCallbackHandler, modules, hooks
            );
            sender = soulWalletFactory.getWalletAddress(initializer, salt);

            /*
            function createWallet(bytes memory _initializer, bytes32 _salt)
            */
            bytes memory soulWalletFactoryCall =
                abi.encodeWithSignature("createWallet(bytes,bytes32)", initializer, salt);
            initCode = abi.encodePacked(address(soulWalletFactory), soulWalletFactoryCall);

            verificationGasLimit = 2000000;
            preVerificationGas = 200000;
            maxFeePerGas = 10 gwei;
            maxPriorityFeePerGas = 10 gwei;
        }

        PackedUserOperation memory userOperation = UserOperationHelper.newUserOp(
            sender,
            nonce,
            initCode,
            callData,
            callGasLimit,
            verificationGasLimit,
            preVerificationGas,
            maxFeePerGas,
            maxPriorityFeePerGas,
            paymasterAndData
        );

        bytes32 userOpHash = entryPoint.getUserOpHash(userOperation);
        (userOpHash);
        userOperation.signature = signUserOp(userOperation, walletOwnerPrivateKey, address(soulWalletDefaultValidator));
        vm.expectRevert();
        bundler.post(entryPoint, userOperation);
        assertEq(sender.code.length, 0, "A1:sender.code.length != 0");

        vm.deal(userOperation.sender, 10 ether);
        bundler.post(entryPoint, userOperation);
        assertEq(sender.code.length > 0, true, "A2:sender.code.length == 0");
        ISoulWallet soulWallet = ISoulWallet(sender);
        assertEq(soulWallet.isOwner(walletOwner.toBytes32()), true);
        assertEq(soulWallet.isOwner(address(0x1111).toBytes32()), false);
    }
}
