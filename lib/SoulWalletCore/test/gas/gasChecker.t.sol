// SPDX-License-Identifier: MIT
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
import {UserOperation} from "@account-abstraction/contracts/interfaces/UserOperation.sol";
import {TokenERC20} from "../dev/TokenERC20.sol";
import {DemoHook} from "../dev/demoHook.sol";
import {DemoModule} from "../dev/demoModule.sol";

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

    function getUserOpHash(UserOperation memory userOp) private view returns (bytes32) {
        return entryPoint.getUserOpHash(userOp);
    }

    function _getRequiredPrefund(UserOperation memory mUserOp) internal pure returns (uint256 requiredPrefund) {
        unchecked {
            //when using a Paymaster, the verificationGasLimit is used also to as a limit for the postOp call.
            // our security model might call postOp eventually twice
            uint256 mul = mUserOp.paymasterAndData.length > 0 ? 3 : 1;
            uint256 requiredGas = mUserOp.callGasLimit + mUserOp.verificationGasLimit * mul + mUserOp.preVerificationGas;

            requiredPrefund = requiredGas * mUserOp.maxFeePerGas;
        }
    }

    function signUserOp(UserOperation memory userOperation) private view {
        bytes32 userOpHash = getUserOpHash(userOperation);
        bytes32 hash = _packHash(userOperation.sender, userOpHash).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(walletOwner1PrivateKey, hash);
        bytes memory _signature = _packSignature(address(validator), abi.encodePacked(r, s, v));
        userOperation.signature = _signature;
    }

    function newUserOp(address sender) private pure returns (UserOperation memory) {
        uint256 nonce = 0;
        bytes memory initCode;
        bytes memory callData;
        uint256 callGasLimit;
        uint256 verificationGasLimit = 1e6;
        uint256 preVerificationGas = 1e5;
        uint256 maxFeePerGas = 100 gwei;
        uint256 maxPriorityFeePerGas = 100 gwei;
        bytes memory paymasterAndData;
        bytes memory signature;
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
        return userOperation;
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

        UserOperation memory userOperation = newUserOp(sender);

        userOperation.verificationGasLimit = 1e6;
        userOperation.preVerificationGas = 1e5;
        userOperation.maxFeePerGas = 100 gwei;
        userOperation.maxPriorityFeePerGas = 100 gwei;
        // function createWallet(bytes memory _initializer, bytes32 _salt)
        userOperation.initCode = abi.encodePacked(
            walletFactory, abi.encodeWithSelector(ProxyFactory.createWallet.selector, initializer, salt)
        );

        signUserOp(userOperation);

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOperation;
        (address beneficiary,) = makeAddrAndKey("beneficiary");
        uint256 preFund = _getRequiredPrefund(userOperation);
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

        UserOperation memory userOperation = newUserOp(sender);
        userOperation.nonce = 1;
        userOperation.callGasLimit = 40000;
        userOperation.callData = abi.encodeWithSelector(walletImpl.execute.selector, address(1), 1 ether, "");
        userOperation.verificationGasLimit = 1e6;
        userOperation.preVerificationGas = 1e5;
        userOperation.maxFeePerGas = 100 gwei;
        userOperation.maxPriorityFeePerGas = 100 gwei;

        signUserOp(userOperation);

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOperation;
        (address beneficiary,) = makeAddrAndKey("beneficiary");
        uint256 preFund = _getRequiredPrefund(userOperation);
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

        UserOperation memory userOperation = newUserOp(sender);

        userOperation.nonce = 1;
        //  function executeBatch(Execution[] calldata executions) external payable virtual override onlyEntryPoint {
        userOperation.callGasLimit = 120000;
        Execution[] memory executions = new Execution[](3);
        executions[0] = Execution(address(1), 0.1 ether, "");
        executions[1] = Execution(address(2), 0.1 ether, "");
        executions[2] = Execution(address(3), 0.1 ether, "");
        userOperation.callData = abi.encodeWithSelector(walletImpl.executeBatch.selector, executions);
        userOperation.verificationGasLimit = 1e6;
        userOperation.preVerificationGas = 1e5;
        userOperation.maxFeePerGas = 100 gwei;
        userOperation.maxPriorityFeePerGas = 100 gwei;

        signUserOp(userOperation);

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOperation;
        (address beneficiary,) = makeAddrAndKey("beneficiary");
        uint256 preFund = _getRequiredPrefund(userOperation);
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

        UserOperation memory userOperation = newUserOp(sender);

        userOperation.nonce = 1;
        // function transfer(address to, uint256 value)
        userOperation.callGasLimit = 40000;
        bytes memory data = abi.encodeWithSelector(token.transfer.selector, address(1), 1 ether);
        userOperation.callData = abi.encodeWithSelector(walletImpl.execute.selector, address(token), 0, data);
        userOperation.verificationGasLimit = 1e6;
        userOperation.preVerificationGas = 1e5;
        userOperation.maxFeePerGas = 100 gwei;
        userOperation.maxPriorityFeePerGas = 100 gwei;

        signUserOp(userOperation);

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOperation;
        (address beneficiary,) = makeAddrAndKey("beneficiary");
        uint256 preFund = _getRequiredPrefund(userOperation);
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

        UserOperation memory userOperation = newUserOp(sender);
        userOperation.nonce = 1;
        // function execute(address target, uint256 value, bytes memory data)
        userOperation.callGasLimit = 120000;
        Execution[] memory executions = new Execution[](3);
        executions[0] =
            Execution(address(token), 0, abi.encodeWithSelector(token.transfer.selector, address(1), 1 ether));
        executions[1] =
            Execution(address(token), 0, abi.encodeWithSelector(token.transfer.selector, address(2), 1 ether));
        executions[2] =
            Execution(address(token), 0, abi.encodeWithSelector(token.transfer.selector, address(3), 1 ether));
        userOperation.callData = abi.encodeWithSelector(walletImpl.executeBatch.selector, executions);
        userOperation.verificationGasLimit = 1e6;
        userOperation.preVerificationGas = 1e5;
        userOperation.maxFeePerGas = 100 gwei;
        userOperation.maxPriorityFeePerGas = 100 gwei;

        signUserOp(userOperation);

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOperation;
        (address beneficiary,) = makeAddrAndKey("beneficiary");
        uint256 preFund = _getRequiredPrefund(userOperation);
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

    // function testHook() public {
    //     (, address sender) = deploy();

    //     // install 1 hook
    //     {
    //         uint256 nonce = 1;
    //         bytes memory initCode;
    //         bytes memory callData;
    //         uint256 callGasLimit;
    //         uint256 verificationGasLimit;
    //         uint256 preVerificationGas;
    //         uint256 maxFeePerGas;
    //         uint256 maxPriorityFeePerGas;
    //         bytes memory paymasterAndData;
    //         bytes memory signature;
    //         bytes memory hookTestData = hex"aabbccddeeffaabbccddeeffaabbccddeeffaabbccddeeffaabbccddeeffaabbccddeeff";
    //         {
    //             // function transfer(address to, uint256 value)
    //             callGasLimit = 200000;
    //             // function installHook(bytes calldata hookAndData, uint8 capabilityFlags)
    //             bytes memory hookAndData = abi.encodePacked(address(demoHook1), hookTestData);
    //             bytes memory data = abi.encodeWithSelector(
    //                 walletImpl.installHook.selector,
    //                 hookAndData,
    //                 PRE_IS_VALID_SIGNATURE_HOOK | PRE_USER_OP_VALIDATION_HOOK
    //             );
    //             callData = abi.encodeWithSelector(walletImpl.execute.selector, sender, 0, data);
    //             verificationGasLimit = 1e6;
    //             preVerificationGas = 1e5;
    //             maxFeePerGas = 100 gwei;
    //             maxPriorityFeePerGas = 100 gwei;
    //         }
    //         UserOperation memory userOperation = UserOperation(
    //             sender,
    //             nonce,
    //             initCode,
    //             callData,
    //             callGasLimit,
    //             verificationGasLimit,
    //             preVerificationGas,
    //             maxFeePerGas,
    //             maxPriorityFeePerGas,
    //             paymasterAndData,
    //             signature
    //         );

    //         signUserOp(userOperation);

    //         UserOperation[] memory ops = new UserOperation[](1);
    //         ops[0] = userOperation;
    //         (address beneficiary,) = makeAddrAndKey("beneficiary");
    //         uint256 preFund = _getRequiredPrefund(userOperation);
    //         require(preFund < 0.2 ether, "preFund too high");
    //         vm.deal(sender, preFund);
    //         vm.expectEmit(true, true, true, true); //   (bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData).
    //         emit InitCalled(hookTestData);
    //         uint256 gasBefore = gasleft();
    //         entryPoint.handleOps(ops, payable(beneficiary));
    //         uint256 gasAfter = gasleft();
    //         uint256 gasCost = gasBefore - gasAfter;
    //         outPutGasCost("Install 1 Hook", gasCost);
    //     }

    //     // uninstall 1 hook
    //     {
    //         uint256 nonce = 2;
    //         bytes memory initCode;
    //         bytes memory callData;
    //         uint256 callGasLimit;
    //         uint256 verificationGasLimit;
    //         uint256 preVerificationGas;
    //         uint256 maxFeePerGas;
    //         uint256 maxPriorityFeePerGas;
    //         bytes memory paymasterAndData;
    //         bytes memory signature;
    //         {
    //             // function transfer(address to, uint256 value)
    //             callGasLimit = 200000;
    //             // function uninstallHook(address hookAddress)
    //             bytes memory data = abi.encodeWithSelector(walletImpl.uninstallHook.selector, demoHook1);
    //             callData = abi.encodeWithSelector(walletImpl.execute.selector, sender, 0, data);
    //             verificationGasLimit = 1e6;
    //             preVerificationGas = 1e5;
    //             maxFeePerGas = 100 gwei;
    //             maxPriorityFeePerGas = 100 gwei;
    //         }
    //         UserOperation memory userOperation = UserOperation(
    //             sender,
    //             nonce,
    //             initCode,
    //             callData,
    //             callGasLimit,
    //             verificationGasLimit,
    //             preVerificationGas,
    //             maxFeePerGas,
    //             maxPriorityFeePerGas,
    //             paymasterAndData,
    //             signature
    //         );

    //         signUserOp(userOperation);

    //         UserOperation[] memory ops = new UserOperation[](1);
    //         ops[0] = userOperation;
    //         (address beneficiary,) = makeAddrAndKey("beneficiary");
    //         uint256 preFund = _getRequiredPrefund(userOperation);
    //         require(preFund < 0.2 ether, "preFund too high");
    //         vm.deal(sender, preFund);
    //         vm.expectEmit(true, true, true, true); //   (bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData).
    //         emit DeInitCalled();
    //         uint256 gasBefore = gasleft();
    //         entryPoint.handleOps(ops, payable(beneficiary));
    //         uint256 gasAfter = gasleft();
    //         uint256 gasCost = gasBefore - gasAfter;
    //         outPutGasCost("Uninstall 1 Hook", gasCost);
    //     }

    //     // install 2 hooks
    //     {
    //         uint256 nonce = 3;
    //         bytes memory initCode;
    //         bytes memory callData;
    //         uint256 callGasLimit;
    //         uint256 verificationGasLimit;
    //         uint256 preVerificationGas;
    //         uint256 maxFeePerGas;
    //         uint256 maxPriorityFeePerGas;
    //         bytes memory paymasterAndData;
    //         bytes memory signature;
    //         bytes memory hookTestData = hex"aabbccddeeffaabbccddeeffaabbccddeeffaabbccddeeffaabbccddeeffaabbccddeeff";
    //         {
    //             // function transfer(address to, uint256 value)
    //             callGasLimit = 500000;
    //             // function installHook(bytes calldata hookAndData, uint8 capabilityFlags)
    //             bytes memory hookAndData1 = abi.encodePacked(address(demoHook1), hookTestData);
    //             bytes memory hookAndData2 = abi.encodePacked(address(demoHook2));
    //             bytes memory data1 = abi.encodeWithSelector(
    //                 walletImpl.installHook.selector,
    //                 hookAndData1,
    //                 PRE_IS_VALID_SIGNATURE_HOOK | PRE_USER_OP_VALIDATION_HOOK
    //             );
    //             bytes memory data2 = abi.encodeWithSelector(
    //                 walletImpl.installHook.selector,
    //                 hookAndData2,
    //                 PRE_IS_VALID_SIGNATURE_HOOK | PRE_USER_OP_VALIDATION_HOOK
    //             );
    //             Execution[] memory executions = new Execution[](2);
    //             executions[0] = Execution(address(walletImpl), 0, data1);
    //             executions[1] = Execution(address(walletImpl), 0, data2);
    //             callData = abi.encodeWithSelector(walletImpl.executeBatch.selector, executions);
    //             verificationGasLimit = 1e6;
    //             preVerificationGas = 1e5;
    //             maxFeePerGas = 100 gwei;
    //             maxPriorityFeePerGas = 100 gwei;
    //         }
    //         UserOperation memory userOperation = UserOperation(
    //             sender,
    //             nonce,
    //             initCode,
    //             callData,
    //             callGasLimit,
    //             verificationGasLimit,
    //             preVerificationGas,
    //             maxFeePerGas,
    //             maxPriorityFeePerGas,
    //             paymasterAndData,
    //             signature
    //         );

    //         signUserOp(userOperation);

    //         UserOperation[] memory ops = new UserOperation[](1);
    //         ops[0] = userOperation;
    //         (address beneficiary,) = makeAddrAndKey("beneficiary");
    //         uint256 preFund = _getRequiredPrefund(userOperation);
    //         require(preFund < 0.2 ether, "preFund too high");
    //         vm.deal(sender, preFund);
    //         // vm.expectEmit(true, true, true, true); //   (bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData).
    //         // emit InitCalled(hookTestData);
    //         // emit InitCalled("");
    //         uint256 gasBefore = gasleft();
    //         entryPoint.handleOps(ops, payable(beneficiary));
    //         uint256 gasAfter = gasleft();
    //         uint256 gasCost = gasBefore - gasAfter;
    //         outPutGasCost("Install 2 Hooks", gasCost);
    //     }

    //     // transfer ETH with 2 hook
    //     {
    //         uint256 nonce = 4;
    //         bytes memory initCode;
    //         bytes memory callData;
    //         uint256 callGasLimit;
    //         uint256 verificationGasLimit;
    //         uint256 preVerificationGas;
    //         uint256 maxFeePerGas;
    //         uint256 maxPriorityFeePerGas;
    //         bytes memory paymasterAndData;
    //         bytes memory signature;
    //         {
    //             // function execute(address target, uint256 value, bytes memory data)
    //             callGasLimit = 40000;
    //             callData = abi.encodeWithSelector(walletImpl.execute.selector, address(1), 1 ether, "");
    //             verificationGasLimit = 1e6;
    //             preVerificationGas = 1e5;
    //             maxFeePerGas = 100 gwei;
    //             maxPriorityFeePerGas = 100 gwei;
    //         }
    //         UserOperation memory userOperation = UserOperation(
    //             sender,
    //             nonce,
    //             initCode,
    //             callData,
    //             callGasLimit,
    //             verificationGasLimit,
    //             preVerificationGas,
    //             maxFeePerGas,
    //             maxPriorityFeePerGas,
    //             paymasterAndData,
    //             signature
    //         );

    //         signUserOp(userOperation);

    //         UserOperation[] memory ops = new UserOperation[](1);
    //         ops[0] = userOperation;
    //         (address beneficiary,) = makeAddrAndKey("beneficiary");
    //         uint256 preFund = _getRequiredPrefund(userOperation);
    //         require(preFund < 0.2 ether, "preFund too high");
    //         vm.deal(sender, preFund + 1 ether);
    //         uint256 gasBefore = gasleft();
    //         entryPoint.handleOps(ops, payable(beneficiary));
    //         uint256 gasAfter = gasleft();
    //         console.log("address(1).balance,", address(1).balance);
    //         require(address(1).balance == 1 ether, "ETH transfer failed");
    //         uint256 gasCost = gasBefore - gasAfter;
    //         outPutGasCost("ETH transfer (2 Hooks)", gasCost);
    //     }
    // }
}
