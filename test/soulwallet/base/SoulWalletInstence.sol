// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "./SoulWalletLogicInstence.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {SoulWalletDefaultValidator} from "@source/validator/SoulWalletDefaultValidator.sol";
import "@source/factory/SoulWalletFactory.sol";
import "@source/libraries/TypeConversion.sol";
import "@source/interfaces/ISoulWallet.sol";

contract SoulWalletInstence {
    using TypeConversion for address;
    SoulWalletLogicInstence public soulWalletLogicInstence;
    SoulWalletDefaultValidator public soulWalletDefaultValidator;
    SoulWalletFactory public soulWalletFactory;
    EntryPoint public entryPoint;
    ISoulWallet public soulWallet;

    constructor(
        address defaultCallbackHandler,
        bytes32[] memory owners,
        bytes[] memory modules,
        bytes[] memory hooks,
        bytes32 salt
    ) {
        entryPoint = new EntryPoint();
        soulWalletDefaultValidator = new SoulWalletDefaultValidator();
        soulWalletLogicInstence = new SoulWalletLogicInstence(
            address(entryPoint),
            address(soulWalletDefaultValidator)
        );

        soulWalletFactory = new SoulWalletFactory(
            address(soulWalletLogicInstence.soulWalletLogic()),
            address(entryPoint),
            address(this)
        );

        // soulWalletLogicInstence.initialize(owners, defaultCallbackHandler, modules, hooks);
        bytes memory initializer = abi.encodeWithSignature(
            "initialize(bytes32[],address,bytes[],bytes[])",
            owners,
            defaultCallbackHandler,
            modules,
            hooks
        );
        address walletAddress1 = soulWalletFactory.getWalletAddress(
            initializer,
            salt
        );
        address walletAddress2 = soulWalletFactory.createWallet(
            initializer,
            salt
        );
        require(
            walletAddress1 == walletAddress2,
            "walletAddress1 != walletAddress2"
        );
        require(walletAddress2.code.length > 0, "wallet code is empty");
        // walletAddress1 as SoulWallet
        soulWallet = ISoulWallet(walletAddress1);
    }
}
