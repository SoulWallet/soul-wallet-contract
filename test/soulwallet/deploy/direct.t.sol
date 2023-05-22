// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../base/SoulWalletInstence.sol";

contract DeployDirectTest is Test {
    function setUp() public {}

    function test_Deploy() public {
        (address trustedManagerOwner,) = makeAddrAndKey("trustedManagerOwner");
        IModuleManager.Module[] memory modules = new IModuleManager.Module[](0);
        IPluginManager.Plugin[] memory plugins = new IPluginManager.Plugin[](0);
        bytes32 salt = bytes32(0);
        SoulWalletInstence soulWalletInstence =
            new SoulWalletInstence(trustedManagerOwner, address(0), address(this),  modules, plugins,  salt);
        ISoulWallet soulWallet = soulWalletInstence.soulWallet();
        assertEq(soulWallet.isOwner(address(this)), true);
        assertEq(soulWallet.isOwner(address(0x1111)), false);
    }
}
