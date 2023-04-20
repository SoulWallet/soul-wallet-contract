// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

library CallHelper {
    enum CallType {
        UNKNOWN,
        CALL,
        DELEGATECALL,
        STATICCALL
    }

    function call(
        CallType callType,
        address target,
        bytes memory data
    ) internal returns (bool success, bytes memory returnData) {
        if (callType == CallType.CALL) {
            (success, returnData) = target.call(data);
        } else if (callType == CallType.DELEGATECALL) {
            (success, returnData) = target.delegatecall(data);
        } else if (callType == CallType.STATICCALL) {
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
        if (callType == CallType.CALL) {
            (success, ) = target.call(data);
        } else if (callType == CallType.DELEGATECALL) {
            (success, ) = target.delegatecall(data);
        } else if (callType == CallType.STATICCALL) {
            (success, ) = target.staticcall(data);
        } else {
            revert("CallHelper: INVALID_CALL_TYPE");
        }
        require(success, "CallHelper: CALL_FAILED");
    }
}
