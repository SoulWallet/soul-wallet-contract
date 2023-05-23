// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../base/SoulWalletLogicInstence.sol";
import "@source/SoulWalletFactory.sol";
import "@account-abstraction/contracts/core/EntryPoint.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "@account-abstraction/contracts/interfaces/UserOperation.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../Bundler.sol";
import "@source/dev/Tokens/TokenERC721.sol";
import "@source/handler/DefaultCallbackHandler.sol";

contract DeployProtocolTest is Test {
    using ECDSA for bytes32;

    EntryPoint public entryPoint;
    SoulWalletLogicInstence public soulWalletLogicInstence;
    SoulWalletFactory public soulWalletFactory;
    Bundler public bundler;

    function setUp() public {
        entryPoint = new EntryPoint();
        (address trustedManagerOwner, uint256 trustedManagerOwnerPrivateKey) = makeAddrAndKey("trustedManagerOwner");
        IModuleManager.Module[] memory modules = new IModuleManager.Module[](0);
        IPluginManager.Plugin[] memory plugins = new IPluginManager.Plugin[](0);
        bytes32 salt = bytes32(0);
        soulWalletLogicInstence = new SoulWalletLogicInstence(trustedManagerOwner, entryPoint);
        soulWalletFactory = new SoulWalletFactory(address(soulWalletLogicInstence.soulWalletLogic()));

        bundler = new Bundler();
    }

    function test_Deploy() public {
        address sender;
        uint256 nonce;
        bytes memory initCode;
        bytes memory callData;
        uint256 callGasLimit;
        uint256 verificationGasLimit;
        uint256 preVerificationGas;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        bytes memory paymasterAndData;
        bytes memory signature;

        (address walletOwner, uint256 walletOwnerPrivateKey) = makeAddrAndKey("walletOwner");
        {
            nonce = 0;
            IModuleManager.Module[] memory modules = new IModuleManager.Module[](0);
            IPluginManager.Plugin[] memory plugins = new IPluginManager.Plugin[](0);
            bytes32 salt = bytes32(0);
            DefaultCallbackHandler defaultCallbackHandler = new DefaultCallbackHandler();
            bytes memory initializer = abi.encodeWithSignature(
                "initialize(address,address,(address,bytes4[],bytes)[],(address,bytes)[])",
                walletOwner,
                defaultCallbackHandler,
                modules,
                plugins
            );
            sender = soulWalletFactory.getWalletAddress(initializer, salt);

            /*
            function createWallet(bytes memory _initializer, bytes32 _salt)
            */
            bytes memory soulWalletFactoryCall =
                abi.encodeWithSignature("createWallet(bytes,bytes32)", initializer, salt);
            initCode = abi.encodePacked(address(soulWalletFactory), soulWalletFactoryCall);

            verificationGasLimit = 1000000;
            preVerificationGas = 100000;
            maxFeePerGas = 10 gwei;
            maxPriorityFeePerGas = 10 gwei;
        }

        UserOperation memory userOperation = UserOperation(
            sender,
            nonce,
            initCode,
            callData,
            callGasLimit,
            verificationGasLimit,
            preVerificationGas,
            maxFeePerGas,
            maxPriorityFeePerGas,
            paymasterAndData,
            signature
        );

        bytes32 userOpHash = entryPoint.getUserOpHash(userOperation);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(walletOwnerPrivateKey, userOpHash.toEthSignedMessageHash());
        userOperation.signature = abi.encodePacked(r, s, v);
        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedOp.selector, 0, "AA21 didn't pay prefund"));
        bundler.post(entryPoint, userOperation);
        assertEq(sender.code.length, 0, "A1:sender.code.length != 0");

        vm.deal(userOperation.sender, 10 ether);
        bundler.post(entryPoint, userOperation);
        assertEq(sender.code.length > 0, true, "A2:sender.code.length == 0");
        ISoulWallet soulWallet = ISoulWallet(sender);
        assertEq(soulWallet.isOwner(walletOwner), true);
        assertEq(soulWallet.isOwner(address(0x1111)), false);
    }
}
