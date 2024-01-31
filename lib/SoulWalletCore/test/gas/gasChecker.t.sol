// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {BasicModularAccount} from "../../examples/BasicModularAccount.sol";
import {Execution} from "../../contracts/interface/IStandardExecutor.sol";
import {EOAValidator} from "../../contracts/validators/EOAValidator.sol";
import {ReceiverHandler} from "../dev/ReceiverHandler.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {DeployEntryPoint} from "../dev/deployEntryPoint.sol";
import {ProxyFactory} from "../dev/ProxyFactory.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {TokenERC20} from "../dev/TokenERC20.sol";
import {DemoHook} from "../dev/demoHook.sol";
import {DemoModule} from "../dev/demoModule.sol";
import {UserOperationHelper} from "../dev/userOperationHelper.sol";

contract GasCheckerTest is Test {
    using MessageHashUtils for bytes32;

    IEntryPoint entryPoint;
    ProxyFactory walletFactory;
    BasicModularAccount walletImpl;

    EOAValidator validator;
    ReceiverHandler _fallback;

    TokenERC20 token;
    DemoHook demoHook1;
    DemoHook demoHook2;
    DemoModule demoModule;

    address public walletOwner1;
    uint256 public walletOwner1PrivateKey;
    address public walletOwner2;
    uint256 public walletOwner2PrivateKey;

    function setUp() public {
        entryPoint = new DeployEntryPoint().deploy();
        walletImpl = new BasicModularAccount(address(entryPoint));
        walletFactory = new ProxyFactory(address(walletImpl), address(entryPoint), address(this));
        validator = new EOAValidator();
        _fallback = new ReceiverHandler();
        (walletOwner1, walletOwner1PrivateKey) = makeAddrAndKey("owner1");
        (walletOwner2, walletOwner2PrivateKey) = makeAddrAndKey("owner2");
        token = new TokenERC20();
        demoHook1 = new DemoHook();
        demoHook2 = new DemoHook();
        demoModule = new DemoModule();

        console.log("walletImpl", address(walletImpl));
        console.log("walletFactory", address(walletFactory));
    }

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

    function signUserOp(PackedUserOperation memory userOperation) private view {
        bytes32 userOpHash = getUserOpHash(userOperation);
        bytes32 hash = _packHash(userOperation.sender, userOpHash).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(walletOwner1PrivateKey, hash);
        bytes memory _signature = _packSignature(address(validator), abi.encodePacked(r, s, v));
        userOperation.signature = _signature;
    }

    function deploy() private returns (uint256 gasCost, address sender) {
        bytes32 salt = 0;
        bytes memory initializer;
        {
            bytes32 owner = bytes32(uint256(uint160(walletOwner1)));
            bytes memory defaultValidator = abi.encodePacked(address(validator));
            address defaultFallback = address(_fallback);
            initializer = abi.encodeWithSelector(
                BasicModularAccount.initialize.selector, owner, defaultValidator, defaultFallback
            );
        }
        sender = walletFactory.getWalletAddress(initializer, salt);

        PackedUserOperation memory userOperation = UserOperationHelper.newUserOp(
            sender, // address sender,
            0, // uint256 nonce,
            abi.encodePacked(
                walletFactory, abi.encodeWithSelector(ProxyFactory.createWallet.selector, initializer, salt)
            ), //  bytes memory initCode,
            hex"", // bytes memory callData,
            1e6, // uint256 verificationGasLimit,
            0, //   uint256 callGasLimit,
            1e5, //   uint256 preVerificationGas,
            100 gwei, //   uint256 maxFeePerGas,
            100 gwei, //  uint256 maxPriorityFeePerGas,
            hex"" // bytes memory paymasterAndData
        );

        signUserOp(userOperation);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOperation;
        (address beneficiary,) = makeAddrAndKey("beneficiary");
        uint256 preFund = UserOperationHelper.getRequiredPrefund(userOperation);
        require(preFund < 0.2 ether, "preFund too high");
        vm.deal(sender, preFund);
        uint256 gasBefore = gasleft();
        entryPoint.handleOps(ops, payable(beneficiary));
        uint256 gasAfter = gasleft();
        gasCost = gasBefore - gasAfter;
    }

    function testDeploy() public {
        (uint256 gasCost,) = deploy();
        outPutGasCost("Deploy Account", gasCost);
    }

    function outPutGasCost(string memory name, uint256 gasCost) private view {
        console.log("gasChecker\t", name, "\t", gasCost);
    }

    function testETHTransfer() public {
        (, address sender) = deploy();

        PackedUserOperation memory userOperation = UserOperationHelper.newUserOp(
            sender, // address sender,
            1, // uint256 nonce,
            hex"", //  bytes memory initCode,
            abi.encodeWithSelector(walletImpl.execute.selector, address(1), 1 ether, ""), // bytes memory callData,
            1e6, // uint256 verificationGasLimit,
            40000, //   uint256 callGasLimit,
            1e5, //   uint256 preVerificationGas,
            100 gwei, //   uint256 maxFeePerGas,
            100 gwei, //  uint256 maxPriorityFeePerGas,
            hex"" // bytes memory paymasterAndData
        );

        signUserOp(userOperation);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOperation;
        (address beneficiary,) = makeAddrAndKey("beneficiary");
        uint256 preFund = UserOperationHelper.getRequiredPrefund(userOperation);
        require(preFund < 0.2 ether, "preFund too high");
        vm.deal(sender, preFund + 1 ether);
        uint256 gasBefore = gasleft();
        entryPoint.handleOps(ops, payable(beneficiary));
        uint256 gasAfter = gasleft();
        console.log("address(1).balance,", address(1).balance);
        require(address(1).balance == 1 ether, "ETH transfer failed");
        uint256 gasCost = gasBefore - gasAfter;
        outPutGasCost("ETH transfer", gasCost);
    }

    function testBatchETHTransfer() public {
        (, address sender) = deploy();

        Execution[] memory executions = new Execution[](3);
        executions[0] = Execution(address(1), 0.1 ether, "");
        executions[1] = Execution(address(2), 0.1 ether, "");
        executions[2] = Execution(address(3), 0.1 ether, "");

        PackedUserOperation memory userOperation = UserOperationHelper.newUserOp(
            sender, // address sender,
            1, // uint256 nonce,
            hex"", //  bytes memory initCode,
            abi.encodeWithSelector(walletImpl.executeBatch.selector, executions), // bytes memory callData,
            1e6, // uint256 verificationGasLimit,
            120000, //   uint256 callGasLimit,
            1e5, //   uint256 preVerificationGas,
            100 gwei, //   uint256 maxFeePerGas,
            100 gwei, //  uint256 maxPriorityFeePerGas,
            hex"" // bytes memory paymasterAndData
        );

        signUserOp(userOperation);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOperation;
        (address beneficiary,) = makeAddrAndKey("beneficiary");
        uint256 preFund = UserOperationHelper.getRequiredPrefund(userOperation);
        require(preFund < 0.2 ether, "preFund too high");
        vm.deal(sender, preFund + 1 ether);
        uint256 gasBefore = gasleft();
        entryPoint.handleOps(ops, payable(beneficiary));
        uint256 gasAfter = gasleft();
        console.log("address(1).balance,", address(1).balance);
        require(address(1).balance == 0.1 ether, "ETH transfer failed");
        uint256 gasCost = gasBefore - gasAfter;
        outPutGasCost("ETH batch transfer", gasCost / 3);
    }

    function testERC20Transfer() public {
        (, address sender) = deploy();

        token.transfer(sender, 1 ether);

        bytes memory data = abi.encodeWithSelector(token.transfer.selector, address(1), 1 ether);

        PackedUserOperation memory userOperation = UserOperationHelper.newUserOp(
            sender, // address sender,
            1, // uint256 nonce,
            hex"", //  bytes memory initCode,
            abi.encodeWithSelector(walletImpl.execute.selector, address(token), 0, data), // bytes memory callData,
            1e6, // uint256 verificationGasLimit,
            40000, //   uint256 callGasLimit,
            1e5, //   uint256 preVerificationGas,
            100 gwei, //   uint256 maxFeePerGas,
            100 gwei, //  uint256 maxPriorityFeePerGas,
            hex"" // bytes memory paymasterAndData
        );

        signUserOp(userOperation);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOperation;
        (address beneficiary,) = makeAddrAndKey("beneficiary");
        uint256 preFund = UserOperationHelper.getRequiredPrefund(userOperation);
        require(preFund < 0.2 ether, "preFund too high");
        vm.deal(sender, preFund);
        require(token.balanceOf(address(1)) == 0 ether);
        uint256 gasBefore = gasleft();
        entryPoint.handleOps(ops, payable(beneficiary));
        uint256 gasAfter = gasleft();
        console.log("address(1).balance,", token.balanceOf(address(1)));
        require(token.balanceOf(address(1)) == 1 ether, "ERC20 transfer failed");
        uint256 gasCost = gasBefore - gasAfter;
        outPutGasCost("ERC20 transfer", gasCost);
    }

    function testBatchERC20Transfer() public {
        (, address sender) = deploy();
        token.transfer(sender, 3 ether);

        // function execute(address target, uint256 value, bytes memory data)
        Execution[] memory executions = new Execution[](3);
        executions[0] =
            Execution(address(token), 0, abi.encodeWithSelector(token.transfer.selector, address(1), 1 ether));
        executions[1] =
            Execution(address(token), 0, abi.encodeWithSelector(token.transfer.selector, address(2), 1 ether));
        executions[2] =
            Execution(address(token), 0, abi.encodeWithSelector(token.transfer.selector, address(3), 1 ether));

        PackedUserOperation memory userOperation = UserOperationHelper.newUserOp(
            sender, // address sender,
            1, // uint256 nonce,
            hex"", //  bytes memory initCode,
            abi.encodeWithSelector(walletImpl.executeBatch.selector, executions), // bytes memory callData,
            1e6, // uint256 verificationGasLimit,
            120000, //   uint256 callGasLimit,
            1e5, //   uint256 preVerificationGas,
            100 gwei, //   uint256 maxFeePerGas,
            100 gwei, //  uint256 maxPriorityFeePerGas,
            hex"" // bytes memory paymasterAndData
        );

        signUserOp(userOperation);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOperation;
        (address beneficiary,) = makeAddrAndKey("beneficiary");
        uint256 preFund = UserOperationHelper.getRequiredPrefund(userOperation);
        require(preFund < 0.2 ether, "preFund too high");
        vm.deal(sender, preFund);
        require(token.balanceOf(address(1)) == 0 ether);
        require(token.balanceOf(address(2)) == 0 ether);
        require(token.balanceOf(address(3)) == 0 ether);
        uint256 gasBefore = gasleft();
        entryPoint.handleOps(ops, payable(beneficiary));
        uint256 gasAfter = gasleft();
        console.log("address(3).balance,", token.balanceOf(address(3)));
        require(token.balanceOf(address(1)) == 1 ether, "ERC20 transfer failed");
        require(token.balanceOf(address(2)) == 1 ether, "ERC20 transfer failed");
        require(token.balanceOf(address(3)) == 1 ether, "ERC20 transfer failed");
        uint256 gasCost = gasBefore - gasAfter;
        outPutGasCost("ERC20 batch transfer", gasCost / 3);
    }

    uint8 internal constant PRE_IS_VALID_SIGNATURE_HOOK = 1 << 0;
    uint8 internal constant PRE_USER_OP_VALIDATION_HOOK = 1 << 1;

    event InitCalled(bytes data);
    event DeInitCalled();
}
