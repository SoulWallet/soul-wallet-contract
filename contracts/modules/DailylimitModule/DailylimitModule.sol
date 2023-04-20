// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./IDailylimitModule.sol";
import "../../libraries/CallHelper.sol";

contract DailylimitModule is IDailylimitModule {
    mapping(address => mapping(address => uint)) private dailyLimit;
    mapping(address => mapping(address => uint)) private spentToday;


    bytes4 private constant _methodId1 = bytes4(keccak256("setDailyLimit(address,uint256)"));
    bytes4 private constant _methodId2 = bytes4(keccak256("resetSpentToday(address)"));
    bytes4 private constant _methodId3 = bytes4(keccak256("getDailyLimit(address)"));
    bytes4 private constant _methodId4 = bytes4(keccak256("getSpentToday(address)"));

    constructor() {}

    function supportsInterface(
        bytes4 interfaceId
    ) public view returns (bool) {
        return interfaceId == type(IModule).interfaceId;
    }

    function supportsMethod(
        bytes4 methodId
    ) public view returns (CallHelper.CallType) {

        if( methodId == _methodId1 ||
            methodId == _methodId2 ||
            methodId == _methodId3 ||
            methodId == _methodId4) {
            return CallHelper.CallType.CALL;
        }
        return CallHelper.CallType.UNKNOWN;
    }

    function supportsHook(HookType hookType) external view returns (CallHelper.CallType) {
        return CallHelper.CallType.CALL;
    }

    function preHook(
        address target,
        uint256 value,
        bytes memory data
    ) external {}

    function postHook(
        address target,
        uint256 value,
        bytes memory data
    ) external {}


    function setDailyLimit(address token, uint256 limit) external {
        dailyLimit[msg.sender][token] = limit;
    }

    function resetSpentToday(address token) external {
        spentToday[msg.sender][token] = 0;
    }

    function getDailyLimit(address token) public view returns (uint256) {
        return dailyLimit[msg.sender][token];
    }

    function getSpentToday(address token) public view returns (uint256) {
        return spentToday[msg.sender][token];
    }
}
