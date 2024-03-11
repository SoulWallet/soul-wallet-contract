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
import {BytesLibTest} from "../helper/BytesLib.t.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IStandardExecutor} from "@soulwallet-core/contracts/interface/IStandardExecutor.sol";
import "@source/libraries/TypeConversion.sol";
import {UserOperationHelper} from "@soulwallet-core/test/dev/userOperationHelper.sol";

contract ERC20PaymasterTest is Test, UserOpHelper {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    using TypeConversion for address;

    SoulWalletInstence soulWalletInstence;
    ISoulWallet soulWallet;
    ERC20Paymaster paymaster;
    Bundler bundler;

    address ownerAddr;
    uint256 ownerKey;

    address paymasterOwner;
    address payable beneficiary;
    TokenERC20 token;
    TestOracle testOracle;
    TestOracle nativeAssetOracle;
    HelloWorld helloWorld;

    function setUp() public {
        (ownerAddr, ownerKey) = makeAddrAndKey("owner1");
        paymasterOwner = makeAddr("paymasterOwner");
        beneficiary = payable(makeAddr("beneficiary"));

        token = new TokenERC20(6);
        testOracle = new TestOracle(166590000);
        nativeAssetOracle = new TestOracle(190355094900);
        helloWorld = new HelloWorld();
        bundler = new Bundler();
        bytes[] memory modules = new bytes[](0);
        bytes[] memory hooks = new bytes[](0);
        bytes32 salt = bytes32(0);
        bytes32[] memory owners = new bytes32[](1);
        owners[0] = address(ownerAddr).toBytes32();
        DefaultCallbackHandler defaultCallbackHandler = new DefaultCallbackHandler();
        soulWalletInstence = new SoulWalletInstence(address(defaultCallbackHandler), owners, modules, hooks, salt);
        soulWallet = soulWalletInstence.soulWallet();
        entryPoint = soulWalletInstence.entryPoint();

        paymaster = new ERC20Paymaster(entryPoint, paymasterOwner, soulWalletInstence.soulWalletFactory.address);

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
        vm.stopPrank();

        vm.warp(1685300000);
    }

    function testSetup() external {
        assertEq(address(paymaster.entryPoint()), address(entryPoint));
        assertEq(paymaster.isSupportToken(address(token)), true);
        assertEq(address(paymaster.owner()), paymasterOwner);
    }

    function testWithdrawToken(uint256 _amount) external {
        vm.assume(_amount < token.totalSupply());
        token.sudoMint(address(paymaster), _amount);
        vm.startPrank(paymasterOwner);
        paymaster.withdrawToken(address(token), beneficiary, _amount);
        assertEq(token.balanceOf(address(paymaster)), 0);
        assertEq(token.balanceOf(beneficiary), _amount);
        vm.stopPrank();
    }

    error OwnableUnauthorizedAccount(address account);

    function testWithdrawTokenFailNotOwner(uint256 _amount) external {
        vm.assume(_amount < token.totalSupply());
        token.sudoMint(address(paymaster), _amount);
        vm.startPrank(beneficiary);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, beneficiary));
        paymaster.withdrawToken(address(token), beneficiary, _amount);
        vm.stopPrank();
    }

    function testWithoutPaymaster() external {
        vm.deal(address(soulWallet), 1e18);
        (PackedUserOperation memory op, uint256 prefund) =
            fillUserOp(soulWallet, ownerKey, address(helloWorld), 0, abi.encodeWithSelector(helloWorld.output.selector));
        (prefund);
        op.signature = signUserOp(
            soulWalletInstence.entryPoint(), op, ownerKey, address(soulWalletInstence.soulWalletDefaultValidator())
        );
        bundler.post(IEntryPoint(entryPoint), op);
    }

    function testERC20Paymaster() external {
        vm.deal(address(soulWallet), 1e18);
        paymaster.updatePrice(address(token));
        token.sudoMint(address(soulWallet), 1000e6);
        token.sudoMint(address(paymaster), 1);
        token.sudoApprove(address(soulWallet), address(paymaster), 1000e6);
        (PackedUserOperation memory op, uint256 prefund) =
            fillUserOp(soulWallet, ownerKey, address(helloWorld), 0, abi.encodeWithSelector(helloWorld.output.selector));
        (prefund);
        vm.breakpoint("a");
        op.paymasterAndData = BytesLibTest.concat(
            abi.encodePacked(address(paymaster), uint128(400000), uint128(400000)),
            abi.encode(address(token), uint256(1000e6))
        );
        vm.breakpoint("b");
        op.signature = signUserOp(
            soulWalletInstence.entryPoint(), op, ownerKey, address(soulWalletInstence.soulWalletDefaultValidator())
        );
        bundler.post(IEntryPoint(entryPoint), op);
    }

    function fillUserOp(ISoulWallet _sender, uint256 _key, address _to, uint256 _value, bytes memory _data)
        public
        returns (PackedUserOperation memory op, uint256 prefund)
    {
        op = UserOperationHelper.newUserOp({
            sender: address(_sender),
            nonce: entryPoint.getNonce(address(_sender), 0),
            initCode: hex"",
            callData: abi.encodeWithSelector(IStandardExecutor.execute.selector, _to, _value, _data),
            callGasLimit: simulateCallGas(entryPoint, op),
            verificationGasLimit: 300000,
            preVerificationGas: 50000,
            maxFeePerGas: 1000000000,
            maxPriorityFeePerGas: 100,
            paymasterAndData: hex""
        });

        op.signature = signUserOp(
            soulWalletInstence.entryPoint(), op, _key, address(soulWalletInstence.soulWalletDefaultValidator())
        );
    }

    function simulateCallGas(EntryPoint _entrypoint, PackedUserOperation memory op) internal returns (uint256) {
        try this.calcGas(_entrypoint, op.sender, op.callData) {
            revert("Should have failed");
        } catch Error(string memory reason) {
            uint256 gas = abi.decode(bytes(reason), (uint256));
            return (gas * 11) / 10;
        } catch {
            revert("Should have failed");
        }
    }

    function calcGas(EntryPoint _entrypoint, address _to, bytes memory _data) external {
        vm.startPrank(address(_entrypoint));
        uint256 g = gasleft();
        (bool success,) = _to.call(_data);
        require(success);
        g = g - gasleft();
        bytes memory r = abi.encode(g);
        vm.stopPrank();
        require(false, string(r));
    }
}
