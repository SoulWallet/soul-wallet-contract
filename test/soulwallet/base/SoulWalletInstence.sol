// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

// import "forge-std/Test.sol";
import "@source/SoulWallet.sol";
import "@source/SoulWalletFactory.sol";
import "./SoulWalletLogicInstence.sol";
import "@source/dev/SingletonFactory.sol";
import "@account-abstraction/contracts/core/EntryPoint.sol";
import "forge-std/Test.sol";

contract SoulWalletInstence {
    SoulWalletLogicInstence public soulWalletLogicInstence;
    SoulWalletFactory public soulWalletFactory;
    SingletonFactory public singletonFactory;
    ISoulWallet public soulWallet;
    EntryPoint public entryPoint;

    constructor(
        address trustedManagerOwner,
        address defaultCallbackHandler,
        address ownerAddr,
        IModuleManager.Module[] memory modules,
        IPluginManager.Plugin[] memory plugins,
        bytes32 salt
    ) {
        entryPoint = new EntryPoint();
        singletonFactory = new SingletonFactory();
        soulWalletLogicInstence = new SoulWalletLogicInstence(trustedManagerOwner, entryPoint);
        soulWalletFactory = new SoulWalletFactory(address(soulWalletLogicInstence.soulWalletLogic()));

        /*
        address anOwner,
        address defalutCallbackHandler,
        Module[] calldata modules,
        Plugin[] calldata plugins
         */
        bytes memory initializer = abi.encodeWithSignature(
            "initialize(address,address,(address,bytes4[],bytes)[],(address,bytes)[])",
            ownerAddr,
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
