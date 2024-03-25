// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import "@source/validator/SoulWalletDefaultValidator.sol";
import {SoulWalletFactory} from "@source/factory/SoulWalletFactory.sol";
import "@source/libraries/TypeConversion.sol";
import {SoulWalletLogicInstence} from "../base/SoulWalletLogicInstence.sol";
import {UserOpHelper} from "../../helper/UserOpHelper.t.sol";
import {UserOperationHelper} from "@soulwallet-core/test/dev/userOperationHelper.sol";
import "@source/abstract/DefaultCallbackHandler.sol";

contract SoulWalletFactoryTest is Test, UserOpHelper {
    using TypeConversion for address;

    SoulWalletDefaultValidator public soulWalletDefaultValidator;
    SoulWalletLogicInstence public soulWalletLogicInstence;
    SoulWalletFactory public soulWalletFactory;
    DefaultCallbackHandler public defaultCallbackHandler;

    function setUp() public {
        defaultCallbackHandler = new DefaultCallbackHandler();
        entryPoint = new EntryPoint();
        soulWalletDefaultValidator = new SoulWalletDefaultValidator();
        soulWalletLogicInstence = new SoulWalletLogicInstence(address(entryPoint), address(soulWalletDefaultValidator));
        address logic = address(soulWalletLogicInstence.soulWalletLogic());

        soulWalletFactory = new SoulWalletFactory(logic, address(entryPoint), address(this));
        require(soulWalletFactory._WALLETIMPL() == logic, "logic address not match");
    }

    function test_deployWallet() public {
        bytes[] memory modules;
        bytes[] memory hooks;
        bytes32[] memory owners = new bytes32[](1);
        owners[0] = address(this).toBytes32();
        bytes32 salt = bytes32(0);
        bytes memory initializer = abi.encodeWithSignature(
            "initialize(bytes32[],address,bytes[],bytes[])", owners, defaultCallbackHandler, modules, hooks
        );
        address walletAddress1 = soulWalletFactory.getWalletAddress(initializer, salt);
        address walletAddress2 = soulWalletFactory.createWallet(initializer, salt);
        require(walletAddress1 == walletAddress2, "walletAddress1 != walletAddress2");
    }
    // test return the wallet account address even if it has already been created

    function test_alreadyDeployedWallet() public {
        bytes[] memory modules;
        bytes[] memory hooks;
        bytes32[] memory owners = new bytes32[](1);
        owners[0] = address(this).toBytes32();
        bytes32 salt = bytes32(0);
        bytes memory initializer = abi.encodeWithSignature(
            "initialize(bytes32[],address,bytes[],bytes[])", owners, defaultCallbackHandler, modules, hooks
        );
        address walletAddress1 = soulWalletFactory.getWalletAddress(initializer, salt);
        address walletAddress2 = soulWalletFactory.createWallet(initializer, salt);
        require(walletAddress1 == walletAddress2, "walletAddress1 != walletAddress2");
        address walletAddress3 = soulWalletFactory.createWallet(initializer, salt);
        require(walletAddress3 == walletAddress2, "walletAddress3 != walletAddress2");
    }
}
