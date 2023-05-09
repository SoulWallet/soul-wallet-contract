// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

library CallHelper {
    enum CallType {
        Unknown,
        Call,
        DelegateCall,
        StaticCall
    }

    function call(
        CallType callType,
        address target,
        bytes memory data
    ) internal returns (bool success, bytes memory returnData) {
        if (callType == CallType.Call) {
            (success, returnData) = target.call(data);
        } else if (callType == CallType.DelegateCall) {
            (success, returnData) = target.delegatecall(data);
        } else if (callType == CallType.StaticCall) {
            (success, returnData) = target.staticcall(data);
        } else {
            revert("CallHelper: INVALID_CALL_TYPE");
        }
    }

    function callWithoutReturnData(
        CallType callType,
        address target,
        bytes memory data
    ) internal {
        bool success;
        if (callType == CallType.Call) {
            (success, ) = target.call(data);
        } else if (callType == CallType.DelegateCall) {
            (success, ) = target.delegatecall(data);
        } else if (callType == CallType.StaticCall) {
            (success, ) = target.staticcall(data);
        } else {
            revert("CallHelper: INVALID_CALL_TYPE");
        }
        require(success, "CallHelper: CALL_FAILED");
    }
}
