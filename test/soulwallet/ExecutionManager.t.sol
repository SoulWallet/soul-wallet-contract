// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "./base/SoulWalletLogicInstence.sol";
import "@source/SoulWalletFactory.sol";
import "@account-abstraction/contracts/core/EntryPoint.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "@account-abstraction/contracts/interfaces/UserOperation.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./Bundler.sol";
import "@source/dev/Tokens/TokenERC721.sol";
import "@source/handler/DefaultCallbackHandler.sol";
import "@source/libraries/Errors.sol";
import "@source/libraries/TypeConversion.sol";
import "@source/validator/DefaultValidator.sol";
import "../helper/UserOpHelper.t.sol";

contract ExecutionManagerTest is Test, UserOpHelper {
    using ECDSA for bytes32;
    using TypeConversion for address;

    SoulWalletLogicInstence public soulWalletLogicInstence;
    SoulWalletFactory public soulWalletFactory;
    Bundler public bundler;
    DefaultValidator defaultValidator;

    function setUp() public {
        entryPoint = new EntryPoint();
        defaultValidator = new DefaultValidator();
        soulWalletLogicInstence = new SoulWalletLogicInstence(entryPoint, defaultValidator);
        soulWalletFactory =
        new SoulWalletFactory(address(soulWalletLogicInstence.soulWalletLogic()), address(entryPoint), address(this));

        bundler = new Bundler();
    }

    function deploy() public returns (address, address) {
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
            bytes[] memory modules = new bytes[](0);
            bytes[] memory plugins = new bytes[](0);
            bytes32 salt = bytes32(0);
            DefaultCallbackHandler defaultCallbackHandler = new DefaultCallbackHandler();
            bytes32[] memory owners = new bytes32[](1);
            owners[0] = walletOwner.toBytes32();
            bytes memory initializer = abi.encodeWithSignature(
                "initialize(bytes32[],address,bytes[],bytes[])", owners, defaultCallbackHandler, modules, plugins
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

        userOperation.signature = signUserOp(userOperation, walletOwnerPrivateKey);
        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedOp.selector, 0, "AA21 didn't pay prefund"));
        bundler.post(entryPoint, userOperation);
        assertEq(sender.code.length, 0, "A1:sender.code.length != 0");

        vm.deal(userOperation.sender, 10 ether);
        bundler.post(entryPoint, userOperation);
        assertEq(sender.code.length > 0, true, "A2:sender.code.length == 0");
        ISoulWallet soulWallet = ISoulWallet(sender);
        assertEq(soulWallet.isOwner(walletOwner.toBytes32()), true);
        assertEq(soulWallet.isOwner(address(0x1111).toBytes32()), false);

        return (sender, walletOwner);
    }

    function test_exec() public {
        (address sender, address walletOwner) = deploy();

        TokenERC721 tokenERC721 = new TokenERC721();

        ISoulWallet soulWallet = ISoulWallet(sender);
        // function execute(address dest, uint256 value, bytes calldata func) external;
        {
            uint256 snapshotId = vm.snapshot();
            {
                tokenERC721.safeMint(sender, 1);
                vm.prank(address(0x111));
                vm.expectRevert(Errors.CALLER_MUST_BE_ENTRYPOINT.selector);
                soulWallet.execute(
                    address(tokenERC721),
                    0,
                    abi.encodeWithSelector(tokenERC721.transferFrom.selector, sender, address(0x111), 1)
                );

                vm.expectRevert(Errors.CALLER_MUST_BE_ENTRYPOINT.selector);
                vm.prank(sender);
                soulWallet.execute(
                    address(tokenERC721),
                    0,
                    abi.encodeWithSelector(tokenERC721.transferFrom.selector, sender, address(0x111), 1)
                );
            }
            {
                tokenERC721.safeMint(sender, 2);
                vm.prank(walletOwner);
                vm.expectRevert(Errors.CALLER_MUST_BE_ENTRYPOINT.selector);
                soulWallet.execute(
                    address(tokenERC721),
                    0,
                    abi.encodeWithSelector(tokenERC721.transferFrom.selector, sender, address(0x111), 2)
                );
            }
            {
                tokenERC721.safeMint(sender, 3);
                vm.prank(address(entryPoint));
                soulWallet.execute(
                    address(tokenERC721),
                    0,
                    abi.encodeWithSelector(tokenERC721.transferFrom.selector, sender, address(0x111), 3)
                );
            }

            vm.revertTo(snapshotId);
        }
        // function executeBatch(address[] calldata dest, bytes[] calldata func)
        {
            uint256 snapshotId = vm.snapshot();
            address[] memory dest = new address[](2);
            dest[0] = address(tokenERC721);
            dest[1] = address(tokenERC721);

            bytes[] memory func = new bytes[](2);
            {
                tokenERC721.safeMint(sender, 4);
                tokenERC721.safeMint(sender, 5);

                func[0] = abi.encodeWithSelector(tokenERC721.transferFrom.selector, sender, address(0x111), 4);
                func[1] = abi.encodeWithSelector(tokenERC721.transferFrom.selector, sender, address(0x111), 5);

                vm.prank(address(0x111));
                vm.expectRevert(Errors.CALLER_MUST_BE_ENTRYPOINT.selector);
                soulWallet.executeBatch(dest, func);
            }
            {
                tokenERC721.safeMint(sender, 6);
                tokenERC721.safeMint(sender, 7);

                func[0] = abi.encodeWithSelector(tokenERC721.transferFrom.selector, sender, address(0x111), 6);
                func[1] = abi.encodeWithSelector(tokenERC721.transferFrom.selector, sender, address(0x111), 7);

                vm.prank(address(entryPoint));
                soulWallet.executeBatch(dest, func);
            }

            vm.revertTo(snapshotId);
        }

        // function executeBatch(address[] calldata dest, uint256[] calldata value, bytes[] calldata func)
        {
            uint256 snapshotId = vm.snapshot();

            address[] memory dest = new address[](2);
            dest[0] = address(tokenERC721);
            dest[1] = address(tokenERC721);

            uint256[] memory value = new uint256[](2);
            value[0] = 0;
            value[1] = 0;

            bytes[] memory func = new bytes[](2);
            {
                tokenERC721.safeMint(sender, 4);
                tokenERC721.safeMint(sender, 5);

                func[0] = abi.encodeWithSelector(tokenERC721.transferFrom.selector, sender, address(0x111), 4);
                func[1] = abi.encodeWithSelector(tokenERC721.transferFrom.selector, sender, address(0x111), 5);

                vm.prank(address(0x111));
                vm.expectRevert(Errors.CALLER_MUST_BE_ENTRYPOINT.selector);
                soulWallet.executeBatch(dest, value, func);
            }
            {
                tokenERC721.safeMint(sender, 6);
                tokenERC721.safeMint(sender, 7);

                func[0] = abi.encodeWithSelector(tokenERC721.transferFrom.selector, sender, address(0x111), 6);
                func[1] = abi.encodeWithSelector(tokenERC721.transferFrom.selector, sender, address(0x111), 7);

                vm.prank(address(entryPoint));
                soulWallet.executeBatch(dest, value, func);
            }
            {
                tokenERC721.safeMint(sender, 8);
                tokenERC721.safeMint(sender, 9);

                func[0] = abi.encodeWithSelector(tokenERC721.transferFrom.selector, sender, address(0x111), 8);
                func[1] = abi.encodeWithSelector(tokenERC721.transferFrom.selector, sender, address(0x111), 9);

                vm.prank(address(entryPoint));
                soulWallet.executeBatch(dest, value, func);
            }
            vm.revertTo(snapshotId);
        }
    }
}
