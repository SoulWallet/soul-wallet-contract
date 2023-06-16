// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@source/libraries/AddressLinkedList.sol";
import "@source/libraries/Errors.sol";

contract AddressLinkedListTest is Test {
    using AddressLinkedList for mapping(address => address);

    mapping(address => address) public list;

    function setUp() public {}

    function test_add_address1() public {
        vm.expectRevert(Errors.INVALID_ADDRESS.selector);
        list.add(address(0x1));
    }

    function test_add() public {
        address addr = makeAddr("random address");
        list.add(addr);
        assertEq(list.size(), 1);
    }

    function test_add10() public {
        for (uint256 i = 0; i < 10; i++) {
            string memory _seed = string(abi.encodePacked("random address(test_add10)", i));
            address addr = makeAddr(_seed);
            assertEq(list.isExist(addr), false);
            list.add(addr);
            assertEq(list.isExist(addr), true);
        }
    }

    function test_replace() public {
        address addr = makeAddr("random address");
        address addr1 = makeAddr("random address1");
        list.add(addr);
        list.add(addr1);
        test_add10();

        address addr2 = makeAddr("random address2");
        list.replace(addr1, addr2);
        assertEq(list.isExist(addr1), false);
        assertEq(list.isExist(addr2), true);

        address addr3 = makeAddr("random address3");
        list.replace(addr, addr3);
        assertEq(list.isExist(addr), false);
        assertEq(list.isExist(addr3), true);
    }

    function test_remove() public {
        address addr = makeAddr("random address");
        list.add(addr);
        assertEq(list.size(), 1);
        list.remove(addr);
        assertEq(list.size(), 0);

        address addr1 = makeAddr("random address1");
        test_add10();
        list.add(addr);
        list.add(addr1);
        assertEq(list.isExist(addr), true);
        assertEq(list.isExist(addr1), true);
        list.remove(addr);
        assertEq(list.isExist(addr), false);
        list.remove(addr1);
        assertEq(list.isExist(addr1), false);
    }

    function test_clear() public {
        assertEq(list.size(), 0);
        list.clear();
        assertEq(list.size(), 0);
        test_add10();
        assertEq(list.size(), 10);
        list.clear();
        assertEq(list.size(), 0);
    }

    function test_isExist() public {
        address addr = makeAddr("random address");
        assertEq(list.isExist(addr), false);
        list.add(addr);
        assertEq(list.isExist(addr), true);
    }

    function test_size() public {
        assertEq(list.size(), 0);
        test_add_address1();
        assertEq(list.size(), 0);

        list.add(address(2));
        assertEq(list.size(), 1);
        list.remove(address(2));
        assertEq(list.size(), 0);
        list.add(address(2));
        list.add(address(3));
        assertEq(list.size(), 2);
        list.remove(address(2));
        assertEq(list.size(), 1);
        list.remove(address(3));
        assertEq(list.size(), 0);

        test_add10();
        assertEq(list.size(), 10);
    }

    function test_isEmpty() public {
        assertEq(list.isEmpty(), true);
        test_add_address1();
        assertEq(list.isEmpty(), false);
    }

    function test_list() public {
        uint256 size = list.size();
        address[] memory _list = list.list(address(0x1), size);
        assertEq(_list.length, 0);
        test_add10();
        size = list.size();
        _list = list.list(address(0x1), size);
        assertEq(_list.length, 10);
    }
}
