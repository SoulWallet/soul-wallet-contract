// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "@source/SoulWallet.sol";
import "@source/SoulWalletFactory.sol";
import "./SoulWalletLogicInstence.sol";
import "@source/dev/SingletonFactory.sol";
import "@account-abstraction/contracts/core/EntryPoint.sol";
import "@source/validator/DefaultValidator.sol";
import "forge-std/Test.sol";
import "@source/libraries/TypeConversion.sol";

contract SoulWalletInstence {
    SoulWalletLogicInstence public soulWalletLogicInstence;
    SoulWalletFactory public soulWalletFactory;
    SingletonFactory public singletonFactory;
    ISoulWallet public soulWallet;
    EntryPoint public entryPoint;
    DefaultValidator public defaultValidator;

    using TypeConversion for address;

    constructor(
        address defaultCallbackHandler,
        address ownerAddr,
        bytes[] memory modules,
        bytes[] memory plugins,
        bytes32 salt
    ) {
        entryPoint = new EntryPoint();

        singletonFactory = new SingletonFactory();
        defaultValidator = new DefaultValidator();
        soulWalletLogicInstence = new SoulWalletLogicInstence(entryPoint, defaultValidator);
        soulWalletFactory =
        new SoulWalletFactory(address(soulWalletLogicInstence.soulWalletLogic()), address(entryPoint), address(this));

        /*
        address anOwner,
        address defalutCallbackHandler,
        Module[] calldata modules,
        Plugin[] calldata plugins
         */
        bytes memory initializer = abi.encodeWithSignature(
            "initialize(bytes32,address,bytes[],bytes[])",
            ownerAddr.toBytes32(),
            defaultCallbackHandler,
            modules,
            plugins
        );
        address walletAddress1 = soulWalletFactory.getWalletAddress(initializer, salt);
        address walletAddress2 = soulWalletFactory.createWallet(initializer, salt);
        require(walletAddress1 == walletAddress2, "walletAddress1 != walletAddress2");
        require(walletAddress2.code.length > 0, "wallet code is empty");
        // walletAddress1 as SoulWallet
        soulWallet = ISoulWallet(walletAddress1);
    }
}
