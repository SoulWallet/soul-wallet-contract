// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {IOwnerManager} from "../contracts/interface/IOwnerManager.sol";
import {BasicModularAccount} from "../examples/BasicModularAccount.sol";
import {Execution} from "../contracts/interface/IStandardExecutor.sol";
import "../contracts/validators/EOAValidator.sol";
import {ReceiverHandler} from "./dev/ReceiverHandler.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {DeployEntryPoint} from "./dev/deployEntryPoint.sol";
import {SoulWalletFactory} from "./dev/SoulWalletFactory.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "../contracts/utils/Constants.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract FallbackManagerTest is Test {
    using MessageHashUtils for bytes32;

    IEntryPoint entryPoint;

    SoulWalletFactory walletFactory;
    BasicModularAccount walletImpl;

    EOAValidator validator;
    ReceiverHandler _fallback;

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

    function test_Fallback() public {
        // send 1eth from walletOwner to address(wallet);
        address _wallet = address(wallet);
        uint256 _1_ether = 1 ether;
        assertEq(address(_wallet).balance, 0);
        bool _1;
        bytes memory _2;
        (_1, _2) = address(_wallet).call{value: _1_ether}("");
        assertEq(address(_wallet).balance, _1_ether);

        (_1, _2) = address(_wallet).call{value: _1_ether}(hex"aa");
        assertEq(address(_wallet).balance, _1_ether * 2);

        vm.expectRevert(CALLER_MUST_BE_SELF_OR_MODULE.selector);
        wallet.setFallbackHandler(address(this));

        vm.startPrank(address(wallet));

        wallet.setFallbackHandler(address(this));
        wallet.setFallbackHandler(address(0));
        vm.stopPrank();

        assertEq(address(_wallet).balance, _1_ether * 2);
        (_1, _2) = address(_wallet).call{value: _1_ether}("");
        assertEq(address(_wallet).balance, _1_ether * 3);

        assertEq(address(_wallet).balance, _1_ether * 3);
        (_1, _2) = address(_wallet).call{value: _1_ether}("aa");
        assertEq(address(_wallet).balance, _1_ether * 4);

        vm.startPrank(address(wallet));
        ITestHandler(address(wallet)).testfunction(address(this));
        // vm.expectRevert();
        ITestHandler(address(wallet)).onERC721Received1(address(this), address(this), 0, "");

        wallet.setFallbackHandler(address(_fallback));
        assertEq(
            IERC721Receiver.onERC721Received.selector,
            ITestHandler(address(wallet)).onERC721Received(address(this), address(this), 0, "")
        );

        vm.stopPrank();
    }
}

interface ITestHandler {
    function testfunction(address sender) external;

    function onERC721Received1(address, address, uint256, bytes calldata) external pure;

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4);
}
