// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

interface IDailylimit {
    event DailyLimitChanged(address[] token, uint256[] limit);
    event PreSetDailyLimit(address[] token, uint256[] limit);
    event CancelSetDailyLimit(address[] token, uint256[] limit);

    function reduceDailyLimits(address[] calldata token, uint256[] calldata amount) external;

    function preSetDailyLimit(address[] calldata token, uint256[] calldata limit) external;

    function cancelSetDailyLimit(address[] calldata token, uint256[] calldata limit) external;

    function comfirmSetDailyLimit(address[] calldata token, uint256[] calldata limit) external;

    function getDailyLimit(address wallet, address token) external view returns (uint256);

    function getSpentToday(address wallet, address token) external view returns (uint256);
}
