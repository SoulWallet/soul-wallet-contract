// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../soulwallet/base/SoulWalletInstence.sol";
import "@source/abstract/DefaultCallbackHandler.sol";
import "@source/paymaster/ERC20Paymaster.sol";
import "@source/dev/tokens/TokenERC20.sol";
import "@source/dev/TestOracle.sol";
import "@source/dev/HelloWorld.sol";
import "../helper/Bundler.t.sol";
import "../helper/UserOpHelper.t.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@source/libraries/TypeConversion.sol";
import {SoulWalletDefaultValidator} from "@source/validator/SoulWalletDefaultValidator.sol";
import {UserOperationHelper} from "@soulwallet-core/test/dev/userOperationHelper.sol";

contract ERC20PaymasterActiveWalletTest is Test, UserOpHelper {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    using TypeConversion for address;

    SoulWalletLogicInstence public soulWalletLogicInstence;
    SoulWalletFactory public soulWalletFactory;
    ISoulWallet soulWallet;
    ERC20Paymaster paymaster;
    Bundler bundler;
    SoulWalletDefaultValidator defaultValidator;

    using TypeConversion for address;

    address ownerAddr;
    uint256 ownerKey;

    address paymasterOwner;
    address payable beneficiary;
    TokenERC20 token;
    TestOracle testOracle;
    TestOracle nativeAssetOracle;
    HelloWorld helloWorld;

    function setUp() public {
        vm.warp(1685300000);
        (ownerAddr, ownerKey) = makeAddrAndKey("owner1");
        paymasterOwner = makeAddr("paymasterOwner");
        beneficiary = payable(makeAddr("beneficiary"));

        token = new TokenERC20(6);
        testOracle = new TestOracle(166590000);
        nativeAssetOracle = new TestOracle(190355094900);
        helloWorld = new HelloWorld();
        bundler = new Bundler();

        entryPoint = new EntryPoint();
        defaultValidator = new SoulWalletDefaultValidator();
        soulWalletLogicInstence = new SoulWalletLogicInstence(address(entryPoint), address(defaultValidator));
        address logic = address(soulWalletLogicInstence.soulWalletLogic());
        soulWalletFactory = new SoulWalletFactory(logic, address(entryPoint), address(this));
        require(soulWalletFactory._WALLETIMPL() == logic, "logic address not match");

        paymaster = new ERC20Paymaster(entryPoint, paymasterOwner, address(soulWalletFactory));

        vm.deal(paymasterOwner, 10000e18);
        vm.startPrank(paymasterOwner);
        paymaster.setNativeAssetOracle(address(nativeAssetOracle));
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
}
