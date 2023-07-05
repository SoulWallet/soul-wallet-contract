// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../base/SoulWalletInstence.sol";
import "../Bundler.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@source/dev/Tokens/TokenERC20.sol";
import "@source/plugin/Dailylimit/Dailylimit.sol";
import "@source/helper/SignatureValidator.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DailylimitTest is Test {
    using ECDSA for bytes32;

    SoulWalletInstence public soulWalletInstence;
    ISoulWallet public soulWallet;
    address public walletOwner;
    uint256 public walletOwnerPrivateKey;
    Bundler public bundler;
    TokenERC20 public token1;
    TokenERC20 public token2;
    TokenERC20 public token3;
    TokenERC20 public token4;
    Dailylimit public dailylimitPlugin;
    EntryPoint public entryPoint;
    address trustedManagerOwner;
    SecurityControlModule public securityControlModule;
    TrustedModuleManager public trustedModuleManager;
    TrustedPluginManager public trustedPluginManager;

    event DailyLimitChanged(address[] token, uint256[] limit);

    function setUp() public {
        (trustedManagerOwner,) = makeAddrAndKey("trustedManagerOwner");
        trustedModuleManager = new TrustedModuleManager(trustedManagerOwner);
        trustedPluginManager = new TrustedPluginManager(trustedManagerOwner);
        securityControlModule = new SecurityControlModule(trustedModuleManager, trustedPluginManager);
        bytes[] memory modules = new bytes[](1);
        modules[0] = abi.encodePacked(securityControlModule, abi.encode(1 days));
        bytes[] memory plugins = new bytes[](0);

        (walletOwner, walletOwnerPrivateKey) = makeAddrAndKey("owner");

        token1 = new TokenERC20(18);
        token2 = new TokenERC20(18);
        token3 = new TokenERC20(18);
        token4 = new TokenERC20(18);

        dailylimitPlugin = new Dailylimit();

        bytes32 salt = bytes32(0);

        // vm.expectEmit(true, true, true, true); //   (bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData).
        // emit DailyLimitChanged(tokens, tokenDailyLimit);
        soulWalletInstence = new SoulWalletInstence(address(0), walletOwner,  modules, plugins,  salt);
        soulWallet = soulWalletInstence.soulWallet();

        bundler = new Bundler();

        vm.deal(address(soulWallet), 10 ether);
        token1.sudoMint(address(soulWallet), 10 ether);
        token2.sudoMint(address(soulWallet), 10 ether);
        token3.sudoMint(address(soulWallet), 10 ether);
        token4.sudoMint(address(soulWallet), 10 ether);

        entryPoint = soulWalletInstence.entryPoint();
    }

    function setUpPlugin() private {
        vm.prank(trustedManagerOwner);
        address[] memory addrs = new address[](1);
        addrs[0] = address(dailylimitPlugin);
        trustedPluginManager.add(addrs);

        bytes memory initData;
        {
            address[] memory tokens = new address[](5);
            tokens[0] = address(0);
            tokens[1] = address(token1);
            tokens[2] = address(token2);
            tokens[3] = address(token3);
            tokens[4] = address(token4);

            uint256[] memory tokenDailyLimit = new uint256[](5);
            tokenDailyLimit[0] = 1 ether;
            tokenDailyLimit[1] = 1 ether;
            tokenDailyLimit[2] = 1 ether;
            tokenDailyLimit[3] = 1 ether;
            tokenDailyLimit[4] = 1 ether;

            initData = abi.encode(tokens, tokenDailyLimit);
        }
        vm.prank(walletOwner);
        securityControlModule.execute(
            address(soulWallet),
            abi.encodeWithSelector(bytes4(keccak256("addPlugin(bytes)")), abi.encodePacked(dailylimitPlugin, initData))
        );

        address[] memory plugins = soulWallet.listPlugin(0);
        assertEq(plugins.length, 1);
        assertEq(plugins[0], address(dailylimitPlugin));
    }

    function getDailylimit()
        private
        view
        returns (uint256 _eth, uint256 _token1, uint256 _token2, uint256 _token3, uint256 _token4)
    {
        _eth = dailylimitPlugin.getDailyLimit(address(soulWallet), address(0));
        _token1 = dailylimitPlugin.getDailyLimit(address(soulWallet), address(token1));
        _token2 = dailylimitPlugin.getDailyLimit(address(soulWallet), address(token2));
        _token3 = dailylimitPlugin.getDailyLimit(address(soulWallet), address(token3));
        _token4 = dailylimitPlugin.getDailyLimit(address(soulWallet), address(token4));
    }

    function getSpentToday()
        private
        view
        returns (uint256 _eth, uint256 _token1, uint256 _token2, uint256 _token3, uint256 _token4)
    {
        _eth = dailylimitPlugin.getSpentToday(address(soulWallet), address(0));

        _token1 = dailylimitPlugin.getSpentToday(address(soulWallet), address(token1));
        _token2 = dailylimitPlugin.getSpentToday(address(soulWallet), address(token2));
        _token3 = dailylimitPlugin.getSpentToday(address(soulWallet), address(token3));
        _token4 = dailylimitPlugin.getSpentToday(address(soulWallet), address(token4));
    }

    function test_dailylimitNow() public {
        setUpPlugin();

        uint256 _eth;
        uint256 _token1;
        uint256 _token2;
        uint256 _token3;
        uint256 _token4;
        (_eth, _token1, _token2, _token3, _token4) = getDailylimit();
        assertEq(_eth, 1 ether);
        assertEq(_token1, 1 ether);
    }

    function transferETH(address to, uint256 amount, bool expectSucc) public {
        address sender = address(soulWallet);
        uint256 nonce = entryPoint.getNonce(sender, 0);
        bytes memory initCode;
        bytes memory callData;
        uint256 callGasLimit;
        uint256 verificationGasLimit;
        uint256 preVerificationGas;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        bytes memory paymasterAndData;
        bytes memory signature;
        {
            callGasLimit = 100000;
            verificationGasLimit = 200000;
            preVerificationGas = 100000;
            maxFeePerGas = 10 gwei;
            maxPriorityFeePerGas = 10 gwei;
            // execute(address dest, uint256 value, bytes calldata func)
            callData = abi.encodeWithSelector(soulWallet.execute.selector, to, amount, "");
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
        uint48 validAfter = uint48(block.timestamp);
        uint48 validUntil = validAfter + 1 hours - 1;
        uint256 validationData = (uint256(validUntil) << 160) | (uint256(validAfter) << (160 + 48));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            walletOwnerPrivateKey, keccak256(abi.encodePacked(userOpHash, validationData)).toEthSignedMessageHash()
        );
        bytes memory sig = abi.encodePacked(r, s, v);

        uint8 signType = 1;
        bytes memory packedSig = abi.encodePacked(signType, validationData, sig);
        userOperation.signature = packedSig;

        uint256 beforeBalance = to.balance;
        bundler.post(entryPoint, userOperation);
        uint256 afterBalance = to.balance;
        if (expectSucc) {
            assertEq(afterBalance - beforeBalance, amount);
        } else {
            assertEq(afterBalance - beforeBalance, 0);
        }
    }

    function transferERC20(address token, address to, uint256 amount, bool expectSucc) public {
        IERC20 tokenContract = IERC20(token);

        address sender = address(soulWallet);
        uint256 nonce = entryPoint.getNonce(sender, 0);
        bytes memory initCode;
        bytes memory callData;
        uint256 callGasLimit;
        uint256 verificationGasLimit;
        uint256 preVerificationGas;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        bytes memory paymasterAndData;
        bytes memory signature;
        {
            callGasLimit = 100000;
            verificationGasLimit = 200000;
            preVerificationGas = 100000;
            maxFeePerGas = 10 gwei;
            maxPriorityFeePerGas = 10 gwei;
            // execute(address dest, uint256 value, bytes calldata func)
            callData = abi.encodeWithSelector(
                soulWallet.execute.selector,
                token,
                0,
                abi.encodeWithSelector(tokenContract.transfer.selector, to, amount)
            );
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
        uint48 validAfter = uint48(block.timestamp);
        uint48 validUntil = validAfter + 1 hours - 1;
        uint256 validationData = (uint256(validUntil) << 160) | (uint256(validAfter) << (160 + 48));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            walletOwnerPrivateKey, keccak256(abi.encodePacked(userOpHash, validationData)).toEthSignedMessageHash()
        );
        bytes memory sig = abi.encodePacked(r, s, v);

        uint8 signType = 1;
        bytes memory packedSig = abi.encodePacked(signType, validationData, sig);
        userOperation.signature = packedSig;

        uint256 beforeBalance = tokenContract.balanceOf(to);
        bundler.post(entryPoint, userOperation);
        uint256 afterBalance = tokenContract.balanceOf(to);
        if (expectSucc) {
            assertEq(afterBalance - beforeBalance, amount);
        } else {
            assertEq(afterBalance - beforeBalance, 0);
        }
    }

    function test_transferETH_dailylimit() public {
        uint256 snapshotId = vm.snapshot();
        setUpPlugin();
        uint256 _eth;
        (_eth,,,,) = getSpentToday();
        assertEq(_eth, 0, "dailylimit should be 0");

        transferETH(address(1), 0.2 ether, true);
        (_eth,,,,) = getSpentToday();
        //console.log("dailylimit 1", _eth);
        assertEq(_eth > 0.2 ether, true, "spentToday should be more than 0.2");

        transferETH(address(1), 0.3 ether, true);
        (_eth,,,,) = getSpentToday();
        //console.log("dailylimit 2", _eth);
        assertEq(_eth > 0.5 ether, true, "spentToday should be more than 0.5");

        transferETH(address(1), 0.5 ether, false);

        vm.warp(block.timestamp + 1 days);
        transferETH(address(1), 0.3 ether, true);
        (_eth,,,,) = getSpentToday();
        //console.log("dailylimit 4", _eth);
        assertEq(_eth > 0.3 ether && _eth < 0.5 ether, true, "spentToday should be more than 0.3 and less than 0.5");

        vm.revertTo(snapshotId);

        //transferETH(address(1), 2 ether);
    }

    function test_transferETH() public {
        transferETH(address(1), 0.2 ether, true);
    }

    function test_transferERC20_dailylimit() public {
        uint256 snapshotId = vm.snapshot();
        setUpPlugin();
        uint256 _token;
        (,, _token,,) = getSpentToday();
        assertEq(_token, 0, "dailylimit should be 0");

        transferERC20(address(token2), address(1), 0.1 ether, true);
        (,, _token,,) = getSpentToday();
        //console.log("dailylimit 1", _eth);
        assertEq(_token, 0.1 ether, "spentToday must be 0.1");

        transferERC20(address(token2), address(1), 0.2 ether, true);
        (,, _token,,) = getSpentToday();
        //console.log("dailylimit 2", _eth);
        assertEq(_token, 0.3 ether, "spentToday must be 0.3");

        transferERC20(address(token2), address(1), 0.8 ether, false);

        vm.warp(block.timestamp + 1 days);
        transferERC20(address(token2), address(1), 0.8 ether, true);

        vm.revertTo(snapshotId);
    }

    function test_transferERC20() public {
        transferERC20(address(token2), address(1), 0.1 ether, true);
    }

    function test_updateDaliylimit() public {
        setUpPlugin();

        uint256 _eth;
        uint256 _token1;
        uint256 _token2;
        uint256 _token3;
        uint256 _token4;
        (_eth, _token1, _token2, _token3, _token4) = getDailylimit();
        assertEq(_eth, 1 ether);
        assertEq(_token1, 1 ether);

        {
            /*
                1. function execDelegateCall(address target, bytes memory data) external
                2. function reduceDailyLimits( address[] calldata token, uint256[] calldata amount) external;
            */

            address[] memory _token = new address[](2);
            uint256[] memory _limit = new uint256[](2);

            _token[0] = address(0);
            _limit[0] = 0.5 ether;

            _token[1] = address(token1);
            _limit[1] = 0.6 ether;

            vm.prank(address(soulWallet));
            dailylimitPlugin.reduceDailyLimits(_token, _limit);
            (_eth, _token1, _token2, _token3, _token4) = getDailylimit();
            assertEq(_eth, 0.5 ether);
            assertEq(_token1, 0.6 ether);
        }
    }

    function test_setDaliylimit() public {
        setUpPlugin();

        uint256 _eth;
        uint256 _token1;
        uint256 _token2;
        uint256 _token3;
        uint256 _token4;
        (_eth, _token1, _token2, _token3, _token4) = getDailylimit();
        assertEq(_eth, 1 ether);
        assertEq(_token1, 1 ether);

        {
            /*
                1. function execDelegateCall(address target, bytes memory data) external
                2. function preSetDailyLimit( address[] calldata token, uint256[] calldata limit ) external;
                3. function comfirmSetDailyLimit( address[] calldata token, uint256[] calldata limit ) external;
            */

            address[] memory _token = new address[](2);
            uint256[] memory _limit = new uint256[](2);

            _token[0] = address(0);
            _limit[0] = 2 ether;

            _token[1] = address(token1);
            _limit[1] = 3 ether;

            {
                vm.prank(address(soulWallet));
                dailylimitPlugin.preSetDailyLimit(_token, _limit);
                // vm.prank(address(entryPoint));
                // soulWallet.execute(
                //     address(soulWallet),
                //     0,
                //     abi.encodeWithSelector(
                //         soulWallet.execDelegateCall.selector,
                //         dailylimitPlugin,
                //         abi.encodeWithSelector(IDailylimit.cancelSetDailyLimit.selector, _token, _limit)
                //     )
                // );
            }
            uint256 PLUGIN_DAILYLIMIT_SAFELOCK_SLOT = 2 days;

            vm.prank(address(soulWallet));
            vm.expectRevert("SafeLock: not unlock time");
            dailylimitPlugin.comfirmSetDailyLimit(_token, _limit);
            vm.warp(block.timestamp + PLUGIN_DAILYLIMIT_SAFELOCK_SLOT);
            vm.prank(address(soulWallet));
            dailylimitPlugin.comfirmSetDailyLimit(_token, _limit);
            (_eth, _token1, _token2, _token3, _token4) = getDailylimit();
            assertEq(_eth, 2 ether);
            assertEq(_token1, 3 ether);
        }
    }
}
