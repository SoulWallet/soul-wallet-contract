// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@source/libraries/DecodeCalldata.sol";

contract DecodeCalldataTest is Test {
    function setUp() public {}

    function something(uint256 a, bool b) external {}

    function test_decodeMethodId() public {
        bytes memory data = abi.encodeWithSelector(DecodeCalldataTest.something.selector);
        bytes4 methodId = DecodeCalldata.decodeMethodId(data);
        assertEq(methodId, DecodeCalldataTest.something.selector);
    }
}
