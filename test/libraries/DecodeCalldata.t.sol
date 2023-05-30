// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@source/libraries/DecodeCalldata.sol";

contract DecodeCalldataTest is Test {
    function setUp() public {}

    function something(uint128 a, bool b, uint256 c) external {}

    function test_decodeMethodId() public {
        uint128 a = 0x111;
        bool b = true;
        uint256 c = 0x222;
        bytes memory data = abi.encodeWithSelector(DecodeCalldataTest.something.selector, a, b, c);
        bytes4 methodId = DecodeCalldata.decodeMethodId(data);
        assertEq(methodId, DecodeCalldataTest.something.selector);
    }

    function test_decodeMethodCalldata() public {
        uint128 a = 0x111;
        bool b = true;
        uint256 c = 0x222;
        bytes memory data = abi.encodeWithSelector(DecodeCalldataTest.something.selector, a, b, c);
        bytes memory methodCalldata = DecodeCalldata.decodeMethodCalldata(data);
        (uint128 _a, bool _b, uint256 _c) = abi.decode(methodCalldata, (uint128, bool, uint256));
        assertEq(_a, a);
        assertEq(_b, b);
        assertEq(_c, c);
        bytes memory expected = abi.encode(a, b, c);
        assertEq(methodCalldata, expected);
    }
}
