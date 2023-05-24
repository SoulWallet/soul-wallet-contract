// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

library CallHelper {
    enum CallType {
        Unknown,
        Call,
        DelegateCall,
        StaticCall
    }

    function call(CallType callType, address target, bytes memory data)
        internal
        returns (bool success, bytes memory returnData)
    {
        if (callType == CallType.Call) {
            (success, returnData) = call(target, data);
        } else if (callType == CallType.DelegateCall) {
            (success, returnData) = delegatecall(target, data);
        } else if (callType == CallType.StaticCall) {
            (success, returnData) = staticcall(target, data);
        } else {
            revert("CallHelper: INVALID_CALL_TYPE");
        }
    }

    function callWithoutReturnData(CallType callType, address target, bytes memory data) internal {
        bool success;
        if (callType == CallType.Call) {
            (success,) = call(target, data);
        } else if (callType == CallType.DelegateCall) {
            (success,) = delegatecall(target, data);
        } else if (callType == CallType.StaticCall) {
            (success,) = staticcall(target, data);
        } else {
            revert("CallHelper: INVALID_CALL_TYPE");
        }
        require(success, "CallHelper: CALL_FAILED");
    }

    function call(address target, bytes memory data) internal returns (bool success, bytes memory returnData) {
        (success, returnData) = target.call{value: 0}(data);
    }

    function delegatecall(address target, bytes memory data) internal returns (bool success, bytes memory returnData) {
        (success, returnData) = target.delegatecall(data);
    }

    function staticcall(address target, bytes memory data)
        internal
        view
        returns (bool success, bytes memory returnData)
    {
        (success, returnData) = target.staticcall(data);
    }
}
