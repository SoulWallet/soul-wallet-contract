// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@source/libraries/Bytes32LinkedList.sol";
import "@source/libraries/Errors.sol";

contract Bytes32LinkedListTest is Test {
    using Bytes32LinkedList for mapping(bytes32 => bytes32);

    mapping(bytes32 => bytes32) public list;

    function setUp() public {}

    function test_add_bytes32_1() public {
        vm.expectRevert(Errors.INVALID_DATA.selector);
        list.add(0x0000000000000000000000000000000000000000000000000000000000000001);
    }

    function test_add() public {
        bytes32 entry = makeBytes32("random entry");
        list.add(entry);
        assertEq(list.size(), 1);
    }

    function test_add10() public {
        for (uint256 i = 0; i < 10; i++) {
            string memory _seed = string(abi.encodePacked("random entry(test_add10)", i));
            bytes32 entry = makeBytes32(_seed);
            assertEq(list.isExist(entry), false);
            list.add(entry);
            assertEq(list.isExist(entry), true);
        }
    }

    function test_replace() public {
        bytes32 entry = makeBytes32("random entry");
        bytes32 entry1 = makeBytes32("random entry1");
        list.add(entry);
        list.add(entry1);
        test_add10();

        bytes32 entry2 = makeBytes32("random entry2");
        list.replace(entry1, entry2);
        assertEq(list.isExist(entry1), false);
        assertEq(list.isExist(entry2), true);

        bytes32 entry3 = makeBytes32("random entry3");
        list.replace(entry, entry3);
        assertEq(list.isExist(entry), false);
        assertEq(list.isExist(entry3), true);
    }

    function makeBytes32(string memory seed) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(seed));
    }
}
