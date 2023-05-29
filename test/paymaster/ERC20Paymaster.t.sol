// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../soulwallet/base/SoulWalletInstence.sol";
import "../soulwallet/Bundler.sol";
import "@source/handler/DefaultCallbackHandler.sol";
import "@source/dev/Tokens/TokenERC721.sol";
import "@source/paymaster/ERC20Paymaster.sol";
import "@source/dev/Tokens/TokenERC20.sol";
import "@source/dev/TestOracle.sol";
import "@source/dev/HelloWorld.sol";


using ECDSA for bytes32;

import "../libraries/BytesLib.t.sol";

contract ERC20PaymasterTest is Test {
    EntryPoint entryPoint;
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
    HelloWorld helloWorld;

    function setUp() public {
        (ownerAddr, ownerKey) = makeAddrAndKey("owner1");
        paymasterOwner = makeAddr("paymasterOwner");
        beneficiary = payable(makeAddr("beneficiary"));

        token = new TokenERC20(6);
        testOracle = new TestOracle(190355094900);
        helloWorld = new HelloWorld();
        bundler = new Bundler();
        bytes[] memory modules = new bytes[](0);
        bytes[] memory plugins = new bytes[](0);
        bytes32 salt = bytes32(0);
        DefaultCallbackHandler defaultCallbackHandler = new DefaultCallbackHandler();
        soulWalletInstence =
            new SoulWalletInstence(address(defaultCallbackHandler), ownerAddr,  modules, plugins,  salt);
        soulWallet = soulWalletInstence.soulWallet();
        entryPoint = soulWalletInstence.entryPoint();

        paymaster = new ERC20Paymaster(entryPoint, paymasterOwner, soulWalletInstence.soulWalletFactory.address);


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

    function testWithdrawTokenFailNotOwner(uint256 _amount) external {
        vm.assume(_amount < token.totalSupply());
        token.sudoMint(address(paymaster), _amount);
        vm.startPrank(beneficiary);
        vm.expectRevert("Ownable: caller is not the owner");
        paymaster.withdrawToken(address(token), beneficiary, _amount);
        vm.stopPrank();
    }

    function testWithoutPaymaster() external {
        vm.deal(address(soulWallet), 1e18);
        (UserOperation memory op, uint256 prefund) =
            fillUserOp(soulWallet, ownerKey, address(helloWorld), 0, abi.encodeWithSelector(helloWorld.output.selector));
        op.signature = signUserOp(op, ownerKey);
        bundler.post(IEntryPoint(entryPoint), op);
    }

     function testERC20Paymaster() external {
        vm.deal(address(soulWallet), 1e18);
        paymaster.updatePrice(address(token));
        token.sudoMint(address(soulWallet), 1000e6);
        token.sudoMint(address(paymaster), 1);
        token.sudoApprove(address(soulWallet), address(paymaster), 1000e6);
        (UserOperation memory op, uint256 prefund) =
            fillUserOp(soulWallet, ownerKey, address(helloWorld), 0, abi.encodeWithSelector(helloWorld.output.selector));
        vm.breakpoint("a");
        op.paymasterAndData = BytesLibTest.concat(abi.encodePacked(address(paymaster)), abi.encode(address(token),  uint256(1000e6)));
        vm.breakpoint("b");
        op.signature = signUserOp(op, ownerKey);
        bundler.post(IEntryPoint(entryPoint), op);
    }


    function fillUserOp(ISoulWallet _sender, uint256 _key, address _to, uint256 _value, bytes memory _data)
        public
        returns (UserOperation memory op, uint256 prefund)
    {
        op.sender = address(_sender);
        op.nonce = entryPoint.getNonce(address(_sender), 0);
        op.callData = abi.encodeWithSelector(IExecutionManager.execute.selector, _to, _value, _data);
        op.callGasLimit = 50000;
        op.verificationGasLimit = 80000;
        op.preVerificationGas = 50000;
        op.maxFeePerGas = 1000000000;
        op.maxPriorityFeePerGas = 100;
        op.signature = signUserOp(op, _key);
        (op, prefund) = simulateVerificationGas(entryPoint, op);
        op.callGasLimit = simulateCallGas(entryPoint, op);
    }

    function signUserOp(UserOperation memory op, uint256 _key) public returns (bytes memory signature) {
        bytes32 hash = entryPoint.getUserOpHash(op);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_key, hash.toEthSignedMessageHash());
        signature = abi.encodePacked(r, s, v);
    }

    function simulateVerificationGas(EntryPoint _entrypoint, UserOperation memory op)
        public
        returns (UserOperation memory, uint256 preFund)
    {
        (bool success, bytes memory ret) =
            address(_entrypoint).call(abi.encodeWithSelector(EntryPoint.simulateValidation.selector, op));
        require(!success);
        bytes memory data = BytesLibTest.slice(ret, 4, ret.length - 4);
        (IEntryPoint.ReturnInfo memory retInfo,,,) = abi.decode(
            data, (IEntryPoint.ReturnInfo, IStakeManager.StakeInfo, IStakeManager.StakeInfo, IStakeManager.StakeInfo)
        );
        op.preVerificationGas = retInfo.preOpGas;
        op.verificationGasLimit = retInfo.preOpGas;
        op.maxFeePerGas = retInfo.prefund * 11 / (retInfo.preOpGas * 10);
        op.maxPriorityFeePerGas = 1;
        return (op, retInfo.prefund);
    }

    function simulateCallGas(EntryPoint _entrypoint, UserOperation memory op) internal returns (uint256) {
        try this.calcGas(_entrypoint, op.sender, op.callData) {
            revert("Should have failed");
        } catch Error(string memory reason) {
            uint256 gas = abi.decode(bytes(reason), (uint256));
            return gas * 11 / 10;
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
