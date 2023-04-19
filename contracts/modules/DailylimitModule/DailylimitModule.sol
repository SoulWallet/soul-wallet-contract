// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./IDailylimitModule.sol";

contract DailylimitModule is IDailylimitModule {
    mapping(address => mapping(address => uint)) private dailyLimit;
    mapping(address => mapping(address => uint)) private spentToday;

    constructor() {}

    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return interfaceId == type(IModule).interfaceId;
    }

    function supportsStaticCall(
        bytes4 methodId
    ) public view virtual override returns (bool) {
        (methodId);
        return false;
    }

    function supportsDelegateCall(
        bytes4 methodId
    ) public view virtual override returns (bool) {
        (methodId);
        return false;
    }

    function supportsHook(
        bytes4 hookId
    ) public view virtual override returns (bool) {
        (hookId);
        return false;
    }

    function delegateCallBeforeExecution(
        address target,
        uint256 value,
        bytes memory data
    ) public virtual override {
        (target, value, data);
    }

    function delegateCallAfterExecution(
        address target,
        uint256 value,
        bytes memory data
    ) public virtual override {
        (target, value, data);
    }

    function staticCallBeforeExecution(
        address target,
        uint256 value,
        bytes memory data
    ) public view virtual override {
        (target, value, data);
    }

    function staticCallAfterExecution(
        address target,
        uint256 value,
        bytes memory data
    ) public view virtual override {
        (target, value, data);
    }

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
