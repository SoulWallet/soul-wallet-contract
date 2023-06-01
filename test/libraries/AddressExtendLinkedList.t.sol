// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@source/libraries/AddressExtendLinkedList.sol";

contract AddressExtendLinkedListTest is Test {
    using AddressExtendLinkedList for mapping(address => bytes32);

    mapping(address => bytes32) public list;

    function setUp() public {}

    function test_pack() public {
        {
            address a1 = address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF);
            uint96 a1_ext = type(uint96).max;
            bytes32 a1_packed = AddressExtendLinkedList.encode(a1, a1_ext);
            (address _a1, uint96 _a1_ext) = AddressExtendLinkedList.decode(a1_packed);
            assertEq(_a1, a1);
            assertEq(_a1_ext, a1_ext);
            assertEq(AddressExtendLinkedList.decodeAddress(a1_packed), a1);
        }
        {
            address a1 = address(0);
            uint96 a1_ext = type(uint96).max;
            bytes32 a1_packed = AddressExtendLinkedList.encode(a1, a1_ext);
            (address _a1, uint96 _a1_ext) = AddressExtendLinkedList.decode(a1_packed);
            assertEq(_a1, a1);
            assertEq(_a1_ext, a1_ext);
            assertEq(AddressExtendLinkedList.decodeAddress(a1_packed), a1);
        }
        {
            address a1 = address(1);
            uint96 a1_ext = type(uint96).max;
            bytes32 a1_packed = AddressExtendLinkedList.encode(a1, a1_ext);
            (address _a1, uint96 _a1_ext) = AddressExtendLinkedList.decode(a1_packed);
            assertEq(_a1, a1);
            assertEq(_a1_ext, a1_ext);
            assertEq(AddressExtendLinkedList.decodeAddress(a1_packed), a1);
        }

        {
            address a1 = address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF);
            uint96 a1_ext = 0;
            bytes32 a1_packed = AddressExtendLinkedList.encode(a1, a1_ext);
            (address _a1, uint96 _a1_ext) = AddressExtendLinkedList.decode(a1_packed);
            assertEq(_a1, a1);
            assertEq(_a1_ext, a1_ext);
            assertEq(AddressExtendLinkedList.decodeAddress(a1_packed), a1);
        }
        {
            address a1 = address(0);
            uint96 a1_ext = 0;
            bytes32 a1_packed = AddressExtendLinkedList.encode(a1, a1_ext);
            (address _a1, uint96 _a1_ext) = AddressExtendLinkedList.decode(a1_packed);
            assertEq(_a1, a1);
            assertEq(_a1_ext, a1_ext);
            assertEq(AddressExtendLinkedList.decodeAddress(a1_packed), a1);
        }
        {
            address a1 = address(1);
            uint96 a1_ext = 0;
            bytes32 a1_packed = AddressExtendLinkedList.encode(a1, a1_ext);
            (address _a1, uint96 _a1_ext) = AddressExtendLinkedList.decode(a1_packed);
            assertEq(_a1, a1);
            assertEq(_a1_ext, a1_ext);
            assertEq(AddressExtendLinkedList.decodeAddress(a1_packed), a1);
        }
        {
            address a1 = address(1);
            uint96 a1_ext = 0x111;
            bytes32 a1_packed = AddressExtendLinkedList.encode(a1, a1_ext);
            (address _a1, uint96 _a1_ext) = AddressExtendLinkedList.decode(a1_packed);
            assertEq(_a1, a1);
            assertEq(_a1_ext, a1_ext);
            assertEq(AddressExtendLinkedList.decodeAddress(a1_packed), a1);
            assertEq(AddressExtendLinkedList.decodeExtendData(a1_packed), a1_ext);
        }
    }

    function test_add_address1() public {
        vm.expectRevert(bytes("invalid address"));
        list.add(address(0x1), 0);
    }

    function test_add() public {
        address addr = makeAddr("random address");
        list.add(addr, 0);
        assertEq(list.size(), 1);
    }

    function test_add10() public {
        for (uint256 i = 0; i < 10; i++) {
            string memory _seed = string(abi.encodePacked("random address(test_add10)", i));
            address addr = makeAddr(_seed);
            assertEq(list.isExist(addr), false);
            list.add(addr, 0);
            assertEq(list.isExist(addr), true);
        }
    }

    function test_remove() public {
        address addr = makeAddr("random address");
        list.add(addr, 0);
        assertEq(list.size(), 1);
        list.remove(addr);
        assertEq(list.size(), 0);

        address addr1 = makeAddr("random address1");
        test_add10();
        list.add(addr, 0);
        list.add(addr1, 0);
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
        list.add(addr, 0);
        assertEq(list.isExist(addr), true);
    }

    function test_size() public {
        assertEq(list.size(), 0);
        list.add(address(0x2), 0);
        assertEq(list.size(), 1);
        list.remove(address(0x2));
        assertEq(list.size(), 0);

        list.add(address(0x2), 0);
        assertEq(list.size(), 1);
        list.add(address(0x3), 0);
        assertEq(list.size(), 2);
        list.remove(address(0x2));
        assertEq(list.size(), 1);
        list.remove(address(0x3));
        assertEq(list.size(), 0);

        test_add10();
        assertEq(list.size(), 10);
    }

    function test_isEmpty() public {
        assertEq(list.isEmpty(), true);
        test_add_address1();
        assertEq(list.isEmpty(), false);
    }
}
