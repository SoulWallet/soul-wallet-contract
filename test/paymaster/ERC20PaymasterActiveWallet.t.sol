// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../soulwallet/base/SoulWalletLogicInstence.sol";
import "../soulwallet/Bundler.sol";
import "@source/SoulWalletFactory.sol";
import "@source/handler/DefaultCallbackHandler.sol";
import "@source/dev/Tokens/TokenERC721.sol";
import "@source/paymaster/ERC20Paymaster.sol";
import "@source/dev/Tokens/TokenERC20.sol";
import "@source/dev/TestOracle.sol";
import "@source/dev/HelloWorld.sol";
import "@source/libraries/TypeConversion.sol";
import "@source/validator/DefaultValidator.sol";
import "../helper/UserOpHelper.t.sol";
import "../libraries/BytesLib.t.sol";

contract ERC20PaymasterActiveWalletTest is Test, UserOpHelper {
    using ECDSA for bytes32;

    SoulWalletLogicInstence public soulWalletLogicInstence;
    SoulWalletFactory public soulWalletFactory;
    ISoulWallet soulWallet;
    ERC20Paymaster paymaster;
    Bundler bundler;
    DefaultValidator defaultValidator;

    using TypeConversion for address;

    address ownerAddr;
    uint256 ownerKey;

    address paymasterOwner;
    address payable beneficiary;
    TokenERC20 token;
    TestOracle testOracle;
    HelloWorld helloWorld;

    function setUp() public {
        vm.warp(1685300000);
        (ownerAddr, ownerKey) = makeAddrAndKey("owner1");
        paymasterOwner = makeAddr("paymasterOwner");
        beneficiary = payable(makeAddr("beneficiary"));

        token = new TokenERC20(6);
        testOracle = new TestOracle(190355094900);
        helloWorld = new HelloWorld();
        bundler = new Bundler();

        entryPoint = new EntryPoint();
        defaultValidator = new DefaultValidator();
        soulWalletLogicInstence = new SoulWalletLogicInstence(entryPoint, defaultValidator);
        address logic = address(soulWalletLogicInstence.soulWalletLogic());
        soulWalletFactory = new SoulWalletFactory(logic, address(entryPoint), address(this));
        require(soulWalletFactory.walletImpl() == logic, "logic address not match");

        paymaster = new ERC20Paymaster(entryPoint, paymasterOwner, address(soulWalletFactory));

        vm.deal(paymasterOwner, 10000e18);
        vm.startPrank(paymasterOwner);
        entryPoint.depositTo{value: 1000e18}(address(paymaster));
        paymaster.addStake{value: 1000e18}(1);
        address[] memory tokens = new address[](1);
        tokens[0] = address(token);
        address[] memory oracles = new address[](1);
        oracles[0] = address(testOracle);
        uint32[] memory priceMarkups = new uint32[](1);
        priceMarkups[0] = 1e6;
        paymaster.setToken(tokens, oracles, priceMarkups);
        paymaster.updatePrice(address(token));
        vm.stopPrank();
    }

    function testActiveWalletUsingPaymaster() external {
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

        nonce = 0;

        (address trustedManagerOwner,) = makeAddrAndKey("trustedManagerOwner");
        TrustedModuleManager trustedModuleManager = new TrustedModuleManager(trustedManagerOwner);
        TrustedPluginManager trustedPluginManager = new TrustedPluginManager(trustedManagerOwner);
        SecurityControlModule securityControlModule =
            new SecurityControlModule(trustedModuleManager, trustedPluginManager);

        bytes[] memory modules = new bytes[](1);
        modules[0] = abi.encodePacked(securityControlModule, abi.encode(uint64(2 days)));
        bytes[] memory plugins = new bytes[](0);

        bytes32 salt = bytes32(0);
        bytes32[] memory owners = new bytes32[](1);
        owners[0] = ownerAddr.toBytes32();
        DefaultCallbackHandler defaultCallbackHandler = new DefaultCallbackHandler();
        bytes memory initializer = abi.encodeWithSignature(
            "initialize(bytes32[],address,bytes[],bytes[])", owners, defaultCallbackHandler, modules, plugins
        );
        sender = soulWalletFactory.getWalletAddress(initializer, salt);
        // send wallet with testtoken
        token.sudoMint(address(sender), 1000e6);
        bytes memory soulWalletFactoryCall = abi.encodeWithSignature("createWallet(bytes,bytes32)", initializer, salt);
        initCode = abi.encodePacked(address(soulWalletFactory), soulWalletFactoryCall);

        verificationGasLimit = 2000000;
        preVerificationGas = 500000;
        maxFeePerGas = 10 gwei;
        maxPriorityFeePerGas = 10 gwei;
        callGasLimit = 3000000;

        address[] memory tokenAddressList = new address[](1);
        tokenAddressList[0] = address(token);

        bytes[] memory tokenCallData = new bytes[](1);
        tokenCallData[0] = abi.encodeWithSignature("approve(address,uint256)", address(paymaster), 1000e6);
        callData = abi.encodeWithSignature("executeBatch(address[],bytes[])", tokenAddressList, tokenCallData);
        paymasterAndData =
            abi.encodePacked(abi.encodePacked(address(paymaster)), abi.encode(address(token), uint256(1000e6)));

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

        userOperation.signature = signUserOp(userOperation, ownerKey);
        bundler.post(entryPoint, userOperation);
        soulWallet = ISoulWallet(sender);
        assertEq(soulWallet.isOwner(ownerAddr.toBytes32()), true);
    }
}
