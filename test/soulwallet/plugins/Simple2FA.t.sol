// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../base/SoulWalletInstence.sol";
import "../Bundler.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@source/dev/Tokens/TokenERC20.sol";
import "@source/plugin/Simple2FA/Simple2FA.sol";
import "@source/helper/SignatureValidator.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Simple2FATest is Test {
    using ECDSA for bytes32;

    SoulWalletInstence public soulWalletInstence;
    ISoulWallet public soulWallet;
    address public walletOwner;
    uint256 public walletOwnerPrivateKey;
    Bundler public bundler;
    Simple2FA public simple2FAPlugin;
    EntryPoint public entryPoint;
    address trustedManagerOwner;
    SecurityControlModule public securityControlModule;
    TrustedModuleManager public trustedModuleManager;
    TrustedPluginManager public trustedPluginManager;
    address public simple2FASignAddr;
    uint256 public simple2FASignKey;

    function setUp() public {
        (trustedManagerOwner,) = makeAddrAndKey("trustedManagerOwner");
        trustedModuleManager = new TrustedModuleManager(trustedManagerOwner);
        trustedPluginManager = new TrustedPluginManager(trustedManagerOwner);
        securityControlModule = new SecurityControlModule(trustedModuleManager, trustedPluginManager);
        bytes[] memory modules = new bytes[](1);
        modules[0] = abi.encodePacked(securityControlModule, abi.encode(1 days));
        bytes[] memory plugins = new bytes[](0);

        (walletOwner, walletOwnerPrivateKey) = makeAddrAndKey("owner");

        simple2FAPlugin = new Simple2FA();

        bytes32 salt = bytes32(0);

        // vm.expectEmit(true, true, true, true); //   (bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData).
        // emit DailyLimitChanged(tokens, tokenDailyLimit);
        soulWalletInstence = new SoulWalletInstence(address(0), walletOwner,  modules, plugins,  salt);
        soulWallet = soulWalletInstence.soulWallet();

        bundler = new Bundler();

        vm.deal(address(soulWallet), 10 ether);
        entryPoint = soulWalletInstence.entryPoint();

        (simple2FASignAddr, simple2FASignKey) = makeAddrAndKey("simple2FASignKey");
    }

    function setUpPlugin() private {
        vm.prank(trustedManagerOwner);
        address[] memory addrs = new address[](1);
        addrs[0] = address(simple2FAPlugin);
        trustedPluginManager.add(addrs);
        bytes memory initData = abi.encode(simple2FASignAddr);
        vm.prank(walletOwner);
        securityControlModule.execute(
            address(soulWallet),
            abi.encodeWithSelector(
                bytes4(keccak256("addPlugin(bytes)")), abi.encodePacked(address(simple2FAPlugin), initData)
            )
        );

        address[] memory plugins = soulWallet.listPlugin(0);
        assertEq(plugins.length, 1);
        assertEq(plugins[0], address(simple2FAPlugin));

        assertEq(simple2FAPlugin.signerAddress(address(soulWallet)), simple2FASignAddr);
    }

    function getSignerAddress() private view returns (address _signAddress) {
        return simple2FAPlugin.signerAddress(address(soulWallet));
    }

    function test_2FA() public {
        setUpPlugin();

        address to = address(1);
        uint256 amount = 1 ether;

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

        // generate 2FA signature
        bytes memory guardSig;
        {
            (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(simple2FASignKey, userOpHash.toEthSignedMessageHash());
            bytes memory _sig = abi.encodePacked(_r, _s, _v);
            uint48 _sigLen = uint48(_sig.length);
            guardSig = abi.encodePacked(address(simple2FAPlugin), _sigLen, _sig);
        }

        uint8 signType = 1;
        bytes memory packedSig = abi.encodePacked(signType, validationData, sig, guardSig);
        console.log("guardSig:");
        console.logBytes(guardSig);
        console.log("rawSig:");
        console.logBytes(abi.encodePacked(signType, validationData, sig));
        console.log("packedSig:");
        console.logBytes(packedSig);

        userOperation.signature = packedSig;

        uint256 beforeBalance = to.balance;
        bundler.post(entryPoint, userOperation);
        uint256 afterBalance = to.balance;
        assertEq(afterBalance - beforeBalance, amount);
    }
}
