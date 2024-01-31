// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {IModuleManager} from "../contracts/interface/IModuleManager.sol";
import {IOwnerManager} from "../contracts/interface/IOwnerManager.sol";
import {BasicModularAccount} from "../examples/BasicModularAccount.sol";
import {Execution} from "../contracts/interface/IStandardExecutor.sol";
import "../contracts/validators/EOAValidator.sol";
import {ReceiverHandler} from "./dev/ReceiverHandler.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {DeployEntryPoint} from "./dev/deployEntryPoint.sol";
import {SoulWalletFactory} from "./dev/SoulWalletFactory.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {TokenERC20} from "./dev/TokenERC20.sol";
import {DemoHook} from "./dev/demoHook.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "../contracts/utils/Constants.sol";
import {UserOperationHelper} from "./dev/userOperationHelper.sol";

contract HookManagerTest is Test {
    using MessageHashUtils for bytes32;

    IEntryPoint entryPoint;

    SoulWalletFactory walletFactory;
    BasicModularAccount walletImpl;

    EOAValidator validator;
    ReceiverHandler _fallback;

    TokenERC20 token;
    DemoHook demoHook;

    address public walletOwner;
    uint256 public walletOwnerPrivateKey;

    BasicModularAccount wallet;

    function setUp() public {
        entryPoint = new DeployEntryPoint().deploy();
        walletImpl = new BasicModularAccount(address(entryPoint));
        walletFactory = new SoulWalletFactory(address(walletImpl), address(entryPoint), address(this));
        validator = new EOAValidator();
        _fallback = new ReceiverHandler();
        (walletOwner, walletOwnerPrivateKey) = makeAddrAndKey("owner1");
        token = new TokenERC20();
        demoHook = new DemoHook();

        bytes32 salt = 0;
        bytes memory initializer;
        {
            bytes32 owner = bytes32(uint256(uint160(walletOwner)));
            bytes memory defaultValidator = abi.encodePacked(address(validator));
            address defaultFallback = address(_fallback);
            initializer = abi.encodeWithSelector(
                BasicModularAccount.initialize.selector, owner, defaultValidator, defaultFallback
            );
        }

        wallet = BasicModularAccount(payable(walletFactory.createWallet(initializer, salt)));
    }

    event InitCalled(bytes data);
    event DeInitCalled();

    error CALLER_MUST_BE_SELF_OR_MODULE();
    error INVALID_HOOK();
    error INVALID_HOOK_TYPE();
    error HOOK_NOT_EXISTS();
    error INVALID_HOOK_SIGNATURE();

    function _packHash(address account, bytes32 hash) private view returns (bytes32) {
        uint256 _chainid;
        assembly {
            _chainid := chainid()
        }
        return keccak256(abi.encode(hash, account, _chainid));
    }

    function _packSignature(address validatorAddress, bytes memory signature) private pure returns (bytes memory) {
        uint32 sigLen = uint32(signature.length);
        return abi.encodePacked(validatorAddress, sigLen, signature);
    }

    function getUserOpHash(PackedUserOperation memory userOp) private view returns (bytes32) {
        return entryPoint.getUserOpHash(userOp);
    }

    function signUserOp(PackedUserOperation memory userOperation) private view returns (bytes32 userOpHash) {
        userOpHash = getUserOpHash(userOperation);
        bytes32 hash = _packHash(userOperation.sender, userOpHash).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(walletOwnerPrivateKey, hash);
        bytes memory _signature = _packSignature(address(validator), abi.encodePacked(r, s, v));
        userOperation.signature = _signature;
    }

    function test_Hook() public {
        vm.deal(address(wallet), 1000 ether);
        bytes memory hookData = hex"aabbcc";
        bytes memory hookAndData = abi.encodePacked(address(demoHook), hookData);

        vm.startPrank(address(wallet));

        vm.expectEmit(true, true, true, true); //   (bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData).
        emit InitCalled(hookData);
        wallet.installHook(hookAndData, 3);
        assertTrue(wallet.isInstalledHook(address(demoHook)));

        vm.stopPrank();

        (address[] memory preIsValidSignatureHooks, address[] memory preUserOpValidationHooks) = wallet.listHook();
        assertEq(preIsValidSignatureHooks.length, 1);
        assertEq(preUserOpValidationHooks.length, 1);
        assertEq(preIsValidSignatureHooks[0], address(demoHook));
        assertEq(preUserOpValidationHooks[0], address(demoHook));

        PackedUserOperation memory userOperation = UserOperationHelper.newUserOp(
            address(wallet), // address sender,
            1, // uint256 nonce,
            hex"", //  bytes memory initCode,
            abi.encodeWithSelector(walletImpl.execute.selector, address(10), 1 ether, ""), // bytes memory callData,
            1e6, // uint256 verificationGasLimit,
            200000, //   uint256 callGasLimit,
            1e5, //   uint256 preVerificationGas,
            100 gwei, //   uint256 maxFeePerGas,
            100 gwei, //  uint256 maxPriorityFeePerGas,
            hex"" // bytes memory paymasterAndData
        );

        vm.startPrank(address(entryPoint));

        bytes32 userOpHash = signUserOp(userOperation);
        assertEq(wallet.validateUserOp(userOperation, userOpHash, 1), SIG_VALIDATION_SUCCESS);

        userOperation.callData = abi.encodeWithSelector(walletImpl.execute.selector, address(10), 2 ether, "");
        userOpHash = signUserOp(userOperation);
        assertEq(wallet.validateUserOp(userOperation, userOpHash, 1), SIG_VALIDATION_FAILED);

        vm.stopPrank();

        vm.expectRevert(CALLER_MUST_BE_SELF_OR_MODULE.selector);
        wallet.uninstallHook(address(demoHook));

        vm.startPrank(address(wallet));
        vm.expectEmit(true, true, true, true); //   (bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData).
        emit DeInitCalled();
        wallet.uninstallHook(address(demoHook));
        (address[] memory _preIsValidSignatureHooks, address[] memory _preUserOpValidationHooks) = wallet.listHook();
        assertEq(_preIsValidSignatureHooks.length, 0);
        assertEq(_preUserOpValidationHooks.length, 0);
        vm.stopPrank();
    }

    function test_Hook2() public {
        vm.deal(address(wallet), 1000 ether);
        bytes memory hookData = hex"aabbcc";
        bytes memory hookAndData1 = abi.encodePacked(address(demoHook), hookData);

        // vm.prank(address(wallet));
        vm.expectRevert(CALLER_MUST_BE_SELF_OR_MODULE.selector);
        wallet.installHook(hookAndData1, 3);

        vm.startPrank(address(wallet));
        vm.expectRevert(INVALID_HOOK_TYPE.selector);
        wallet.installHook(hookAndData1, 0);
        vm.stopPrank();

        vm.startPrank(address(wallet));
        vm.expectRevert(INVALID_HOOK.selector);
        wallet.installHook(abi.encodePacked(address(1)), 3);
        vm.stopPrank();

        vm.startPrank(address(wallet));
        vm.expectRevert(HOOK_NOT_EXISTS.selector);
        wallet.uninstallHook(address(demoHook));
        vm.stopPrank();

        DemoHook demoHook2 = new DemoHook();
        DemoHook demoHook3 = new DemoHook();
        DemoHook demoHook4 = new DemoHook();
        DemoHook demoHook5 = new DemoHook();
        bytes memory hookAndData2 = abi.encodePacked(address(demoHook2), hookData);
        bytes memory hookAndData3 = abi.encodePacked(address(demoHook3), hookData);
        bytes memory hookAndData4 = abi.encodePacked(address(demoHook4), hookData);
        bytes memory hookAndData5 = abi.encodePacked(address(demoHook5), hookData);

        vm.startPrank(address(wallet));
        wallet.installHook(hookAndData1, 1);
        wallet.installHook(hookAndData2, 2);
        wallet.installHook(hookAndData3, 3);
        wallet.installHook(hookAndData4, 3);
        wallet.installHook(hookAndData5, 2);

        {
            (address[] memory preIsValidSignatureHooks, address[] memory preUserOpValidationHooks) = wallet.listHook();
            assertEq(preIsValidSignatureHooks.length, 3);
            assertEq(preUserOpValidationHooks.length, 4);

            PackedUserOperation memory userOperation = UserOperationHelper.newUserOp(
                address(wallet), // address sender,
                1, // uint256 nonce,
                hex"", //  bytes memory initCode,
                abi.encodeWithSelector(walletImpl.execute.selector, address(10), 1 ether, ""), // bytes memory callData,
                1e6, // uint256 verificationGasLimit,
                200000, //   uint256 callGasLimit,
                1e5, //   uint256 preVerificationGas,
                100 gwei, //   uint256 maxFeePerGas,
                100 gwei, //  uint256 maxPriorityFeePerGas,
                hex"" // bytes memory paymasterAndData
            );

            // function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
            vm.startPrank(address(entryPoint));

            bytes32 userOpHash = signUserOp(userOperation);
            assertEq(wallet.validateUserOp(userOperation, userOpHash, 1), SIG_VALIDATION_SUCCESS);

            userOperation.callData = abi.encodeWithSelector(walletImpl.execute.selector, address(10), 2 ether, "");
            userOpHash = signUserOp(userOperation);
            assertEq(wallet.validateUserOp(userOperation, userOpHash, 1), SIG_VALIDATION_FAILED);
        }

        vm.stopPrank();
    }

    function testSignature() public {
        vm.deal(address(wallet), 1000 ether);
        DemoHook demoHook2 = new DemoHook();

        bytes memory hookData = hex"aabbcc";
        bytes memory hookAndData = abi.encodePacked(address(demoHook), hookData);
        bytes memory hookAndData2 = abi.encodePacked(address(demoHook2), hookData);

        vm.startPrank(address(wallet));
        wallet.installHook(hookAndData, 3);
        wallet.installHook(hookAndData2, 2);

        PackedUserOperation memory userOperation = UserOperationHelper.newUserOp(
            address(wallet), // address sender,
            1, // uint256 nonce,
            hex"", //  bytes memory initCode,
            abi.encodeWithSelector(walletImpl.execute.selector, address(10), 1 ether, ""), // bytes memory callData,
            1e6, // uint256 verificationGasLimit,
            200000, //   uint256 callGasLimit,
            1e5, //   uint256 preVerificationGas,
            100 gwei, //   uint256 maxFeePerGas,
            100 gwei, //  uint256 maxPriorityFeePerGas,
            hex"" // bytes memory paymasterAndData
        );

        // function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        vm.startPrank(address(entryPoint));

        bytes32 userOpHash = signUserOp(userOperation);
        bytes memory userOpSignature = userOperation.signature;
        {
            bytes memory hookData1 = hex"aa";
            bytes4 hookDataLength1 = bytes4(uint32(uint256(hookData1.length)));
            bytes memory hookSignature = abi.encodePacked(address(0x1), hookDataLength1, hookData1);
            userOperation.signature = abi.encodePacked(userOpSignature, hookSignature);
            vm.expectRevert(INVALID_HOOK_SIGNATURE.selector);
            wallet.validateUserOp(userOperation, userOpHash, 0);
        }
        {
            bytes memory hookData1 = hex"";
            bytes4 hookDataLength1 = bytes4(uint32(uint256(hookData1.length)));
            bytes memory hookSignature = abi.encodePacked(address(0x1), hookDataLength1, hookData1);
            userOperation.signature = abi.encodePacked(userOpSignature, hookSignature);
            vm.expectRevert(); // if iszero(guardSigLen) { revert(0, 0) }
            wallet.validateUserOp(userOperation, userOpHash, 0);
        }
        {
            bytes memory hookData1 = hex"aa";
            bytes memory hookData2 = hex"bb";
            bytes4 hookDataLength1 = bytes4(uint32(uint256(hookData1.length)));
            bytes4 hookDataLength2 = bytes4(uint32(uint256(hookData2.length)));
            bytes memory hookSignature = abi.encodePacked(
                address(demoHook), hookDataLength1, hookData1, address(demoHook2), hookDataLength2, hookData2
            );
            userOperation.signature = abi.encodePacked(userOpSignature, hookSignature);
            assertEq(wallet.validateUserOp(userOperation, userOpHash, 1), SIG_VALIDATION_FAILED);
        }
        {
            bytes memory hookData2 = hex"aabbcc";
            bytes4 hookDataLength2 = bytes4(uint32(uint256(hookData2.length)));
            bytes memory hookSignature = abi.encodePacked(address(demoHook2), hookDataLength2, hookData2);
            userOperation.signature = abi.encodePacked(userOpSignature, hookSignature);
            assertEq(wallet.validateUserOp(userOperation, userOpHash, 1), SIG_VALIDATION_FAILED);
        }
        vm.stopPrank();
    }
}
