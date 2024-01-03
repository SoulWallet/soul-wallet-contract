// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {AddressLinkedList} from "../contracts/utils/AddressLinkedList.sol";
import {Bytes32LinkedList} from "../contracts/utils/Bytes32LinkedList.sol";
import {SelectorLinkedList} from "../contracts/utils/SelectorLinkedList.sol";

contract LinkedListTest is Test {
    using AddressLinkedList for mapping(address => address);
    using Bytes32LinkedList for mapping(bytes32 => bytes32);
    using SelectorLinkedList for mapping(bytes4 => bytes4);

    mapping(address => address) private _addressList;
    mapping(bytes32 => bytes32) private _bytes32List;
    mapping(bytes4 => bytes4) private _selectorList;

    function setUp() public {}

    error INVALID_SELECTOR();
    error SELECTOR_ALREADY_EXISTS();
    error SELECTOR_NOT_EXISTS();

    function test_selectorLinkedList() public {
        assertEq(_selectorList.size(), 0);

        vm.expectRevert(INVALID_SELECTOR.selector);
        _selectorList.add(0x00000000);
        vm.expectRevert(INVALID_SELECTOR.selector);
        _selectorList.add(0x00000001);

        assertEq(_selectorList.size(), 0);

        _selectorList.add(0x00000003);
        _selectorList.add(0x00000002);
        assertEq(_selectorList.size(), 2);
        _selectorList.clear();
        assertFalse(_selectorList.isExist(0x00000003));
        assertFalse(_selectorList.isExist(0x00000002));

        assertEq(_selectorList.size(), 0);
        _selectorList.add(0x00000003);
        _selectorList.add(0x00000002);
        _selectorList.add(0x00000004);
        _selectorList.remove(0x00000002);
        assertTrue(_selectorList.isExist(0x00000003));
        assertFalse(_selectorList.isExist(0x00000002));
        assertTrue(_selectorList.isExist(0x00000004));
        assertEq(_selectorList.size(), 2);
        _selectorList.clear();
        assertEq(_selectorList.size(), 0);
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = 0x00000003;
        selectors[1] = 0x00000002;
        _selectorList.add(selectors);
        assertEq(_selectorList.size(), 2);
        assertTrue(_selectorList.isExist(0x00000003));
        assertTrue(_selectorList.isExist(0x00000002));
        assertFalse(_selectorList.isExist(0x00000004));
    }

    error INVALID_ADDRESS();
    error ADDRESS_ALREADY_EXISTS();
    error ADDRESS_NOT_EXISTS();

    function test_addressLinkedList() public {
        assertEq(_addressList.size(), 0);

        vm.expectRevert(INVALID_ADDRESS.selector);
        _addressList.add(address(0));
        vm.expectRevert(INVALID_ADDRESS.selector);
        _addressList.add(address(1));

        assertEq(_addressList.size(), 0);

        _addressList.add(address(3));
        _addressList.add(address(2));
        assertEq(_addressList.size(), 2);
        _addressList.clear();
        assertEq(_addressList.size(), 0);
        _addressList.add(address(3));
        _addressList.add(address(2));
        assertEq(_addressList.size(), 2);
        assertTrue(_addressList.isExist(address(3)));
        assertTrue(_addressList.isExist(address(2)));
        assertFalse(_addressList.isExist(address(4)));
    }

    error INVALID_DATA();
    error DATA_ALREADY_EXISTS();
    error DATA_NOT_EXISTS();

    function test_bytes32LinkedList() public {
        assertEq(_bytes32List.size(), 0);

        bytes32 _1 = 0x0000000000000000000000000000000000000000000000000000000000000001;
        bytes32 _2 = 0x0000000000000000000000000000000000000000000000000000000000000002;
        bytes32 _3 = 0x0000000000000000000000000000000000000000000000000000000000000003;

        vm.expectRevert(INVALID_DATA.selector);
        _bytes32List.add(bytes32(0));
        vm.expectRevert(INVALID_DATA.selector);
        _bytes32List.add(_1);

        assertEq(_bytes32List.size(), 0);

        _bytes32List.add(_3);
        _bytes32List.add(_2);
        assertEq(_bytes32List.size(), 2);
        _bytes32List.clear();
        assertEq(_bytes32List.size(), 0);
        _bytes32List.add(_3);
        _bytes32List.add(_2);
        assertEq(_bytes32List.size(), 2);
        assertTrue(_bytes32List.isExist(_3));
        assertTrue(_bytes32List.isExist(_2));
        assertFalse(_bytes32List.isExist(keccak256("")));
    }
}
