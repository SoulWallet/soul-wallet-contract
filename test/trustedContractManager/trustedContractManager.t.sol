// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@source/trustedContractManager/trustedModuleManager/TrustedModuleManager.sol";
import "@source/dev/CallHelperTarget.sol";

contract trustedContractManagerTest is Test {
    TrustedModuleManager public trustedModuleManager;
    address public deployAddress = address(0x1111);
    address public ownerAddress = address(0x2222);
    address public moduleAddress;

    function setUp() public {
        vm.prank(deployAddress);
        trustedModuleManager = new TrustedModuleManager(ownerAddress);
        moduleAddress = address(new CallHelperTarget());
    }

    error OwnableUnauthorizedAccount(address account);

    function test_trustedModuleManager() public {
        assertEq(trustedModuleManager.owner(), ownerAddress);
        address newOwnerAddress = address(0x3333);
        vm.prank(deployAddress);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, deployAddress));
        trustedModuleManager.transferOwnership(newOwnerAddress);

        vm.prank(ownerAddress);
        trustedModuleManager.transferOwnership(newOwnerAddress);
        assertEq(trustedModuleManager.owner(), newOwnerAddress);
    }

    function test_addModule() public {
        address[] memory moduleAddresses = new address[](1);
        moduleAddresses[0] = moduleAddress;
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        trustedModuleManager.add(moduleAddresses);

        vm.startPrank(ownerAddress);

        vm.expectRevert(bytes("TrustedContractManager: not a contract"));
        moduleAddresses[0] = address(0x3333);
        trustedModuleManager.add(moduleAddresses);

        assertEq(trustedModuleManager.isTrustedContract(moduleAddress), false);
        moduleAddresses[0] = moduleAddress;
        trustedModuleManager.add(moduleAddresses);
        vm.stopPrank();

        assertEq(trustedModuleManager.isTrustedContract(moduleAddress), true);
    }

    function test_removeModule() public {
        address[] memory moduleAddresses = new address[](1);
        moduleAddresses[0] = moduleAddress;
        vm.startPrank(ownerAddress);
        trustedModuleManager.add(moduleAddresses);
        vm.stopPrank();
        assertEq(trustedModuleManager.isTrustedContract(moduleAddress), true);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        trustedModuleManager.remove(moduleAddresses);
        vm.prank(ownerAddress);
        trustedModuleManager.remove(moduleAddresses);
        assertEq(trustedModuleManager.isTrustedContract(moduleAddress), false);
    }
}
