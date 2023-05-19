// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@source/libraries/CallHelper.sol";
import "@source/dev/CallHelperTarget.sol";

contract CallHelperTest is Test {
    CallHelperTarget public callHelperTarget;
    address public CallHelperTargetAddress;


    bytes32 private constant VALUE_SLOT = keccak256("CallHelperTarget");

    function read() private view returns (uint256 v) {
        bytes32 slot = VALUE_SLOT;
        assembly {
            v := sload(slot)
        }
    }

    function setUp() public {
        callHelperTarget = new CallHelperTarget();
        CallHelperTargetAddress = address(callHelperTarget);
    }

    // function _call1() external onlyCall
    function test_call1() public {
        bytes memory data = abi.encodeWithSelector(CallHelperTarget._call1.selector);
        (bool success, bytes memory returnData) =
            CallHelper.call(CallHelper.CallType.Call, CallHelperTargetAddress, data);
        assertTrue(success);
        assertEq(returnData.length, 0);
    }

    // function _call2() external onlyCall returns (uint256)
    function test_call2() public {
        bytes memory data = abi.encodeWithSelector(CallHelperTarget._call2.selector);
        (bool success, bytes memory returnData) =
            CallHelper.call(CallHelper.CallType.Call, CallHelperTargetAddress, data);
        assertTrue(success);
        assertEq(returnData.length, 32);
        assertEq(abi.decode(returnData, (uint256)), 0x11111);
    }

    // function _call3(uint256 i) external onlyCall returns (uint256)
    function test_call3() public {
        bytes memory data = abi.encodeWithSelector(CallHelperTarget._call3.selector, uint256(0x22222));
        (bool success, bytes memory returnData) =
            CallHelper.call(CallHelper.CallType.Call, CallHelperTargetAddress, data);
        assertTrue(success);
        assertEq(returnData.length, 32);
        assertEq(abi.decode(returnData, (uint256)), 0x22222);
    }

    // function _staticCall1() external view onlyCall
    function test_staticCall1() public {
        bytes memory data = abi.encodeWithSelector(CallHelperTarget._staticCall1.selector);
        (bool success, bytes memory returnData) =
            CallHelper.call(CallHelper.CallType.StaticCall, CallHelperTargetAddress, data);
        assertTrue(success);
        assertEq(returnData.length, 0);
    }

    // function _staticCall2() external view onlyCall returns (uint256)
    function test_staticCall2() public {
        bytes memory data = abi.encodeWithSelector(CallHelperTarget._staticCall2.selector);
        (bool success, bytes memory returnData) =
            CallHelper.call(CallHelper.CallType.StaticCall, CallHelperTargetAddress, data);
        assertTrue(success);
        assertEq(returnData.length, 32);
        assertEq(abi.decode(returnData, (uint256)), 0);
    }

    // function _staticCall3(uint256 i) external view onlyCall returns (uint256)
    function test_staticCall3() public {
        bytes memory data = abi.encodeWithSelector(CallHelperTarget._staticCall3.selector, uint256(0x22222));
        (bool success, bytes memory returnData) =
            CallHelper.call(CallHelper.CallType.StaticCall, CallHelperTargetAddress, data);
        assertTrue(success);
        assertEq(returnData.length, 32);
        assertEq(abi.decode(returnData, (uint256)), 0x22222);
    }

    // function _delegateCall1() external onlyDelegateCall
    function test_delegateCall1() public {
        bytes memory data = abi.encodeWithSelector(CallHelperTarget._delegateCall1.selector);
        (bool success, bytes memory returnData) =
            CallHelper.call(CallHelper.CallType.DelegateCall, CallHelperTargetAddress, data);
        assertTrue(success);
        assertEq(returnData.length, 0);
    }

    // function _delegateCall2() external onlyDelegateCall returns (uint256)
    function test_delegateCall2() public {
        assertEq(read(), 0);
        bytes memory data = abi.encodeWithSelector(CallHelperTarget._delegateCall2.selector);
        (bool success, bytes memory returnData) =
            CallHelper.call(CallHelper.CallType.DelegateCall, CallHelperTargetAddress, data);
        assertTrue(success);
        assertEq(returnData.length, 32);
        assertEq(abi.decode(returnData, (uint256)), 0x11111);
        assertEq(read(), 0x11111);
    }

    // function _delegateCall3(uint256 i) external onlyDelegateCall returns (uint256)
    function test_delegateCall3() public {
        bytes memory data = abi.encodeWithSelector(CallHelperTarget._delegateCall3.selector, uint256(0x22222));
        (bool success, bytes memory returnData) =
            CallHelper.call(CallHelper.CallType.DelegateCall, CallHelperTargetAddress, data);
        assertTrue(success);
        assertEq(returnData.length, 32);
        assertEq(abi.decode(returnData, (uint256)), 0x22222);
    }
}
