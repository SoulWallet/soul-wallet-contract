// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@source/libraries/SelectorLinkedList.sol";
import "@source/libraries/Errors.sol";

contract SelectorLinkedListTest is Test {
    using SelectorLinkedList for mapping(bytes4 => bytes4);

    mapping(bytes4 => bytes4) public list;

    function setUp() public {}

    function test_add_address1() public {
        vm.expectRevert(Errors.INVALID_SELECTOR.selector);
        list.add(0x00000001);
    }

    function test_add() public {
        bytes4 addr = bytes4(keccak256(abi.encodePacked("random address")));
        list.add(addr);
        assertEq(list.size(), 1);
    }

    function test_add10() public {
        for (uint256 i = 0; i < 10; i++) {
            string memory _seed = string(abi.encodePacked("random bytes4(test_add10)", i));
            bytes4 addr = bytes4(keccak256(abi.encodePacked(_seed)));
            assertEq(list.isExist(addr), false);
            list.add(addr);
            assertEq(list.isExist(addr), true);
        }
    }

    function test_replace() public {
        bytes4 addr = bytes4(keccak256(abi.encodePacked("random address")));
        bytes4 addr1 = bytes4(keccak256(abi.encodePacked("random address1")));
        list.add(addr);
        list.add(addr1);
        test_add10();

        bytes4 addr2 = bytes4(keccak256(abi.encodePacked("random address2")));
        list.replace(addr1, addr2);
        assertEq(list.isExist(addr1), false);
        assertEq(list.isExist(addr2), true);

        bytes4 addr3 = bytes4(keccak256(abi.encodePacked("random address3")));
        list.replace(addr, addr3);
        assertEq(list.isExist(addr), false);
        assertEq(list.isExist(addr3), true);
    }

    function test_remove() public {
        bytes4 addr = bytes4(keccak256(abi.encodePacked("random address")));
        list.add(addr);
        assertEq(list.size(), 1);
        list.remove(addr);
        assertEq(list.size(), 0);

        bytes4 addr1 = bytes4(keccak256(abi.encodePacked("random address1")));
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
        bytes4 addr = bytes4(keccak256(abi.encodePacked("random address")));
        assertEq(list.isExist(addr), false);
        list.add(addr);
        assertEq(list.isExist(addr), true);
    }

    function test_size() public {
        assertEq(list.size(), 0);
        test_add_address1();
        assertEq(list.size(), 1);
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
        bytes4[] memory _list = list.list(0x00000001, size);
        assertEq(_list.length, 0);
        test_add10();
        size = list.size();
        _list = list.list(0x00000001, size);
        assertEq(_list.length, 10);
    }
}
