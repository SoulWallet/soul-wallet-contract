// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../interfaces/IModule.sol";

interface IDailylimitModule is IModule {
    function setDailyLimit(address token, uint256 limit) external;
    function resetSpentToday(address token) external;
    function getDailyLimit(address token) external returns (uint256);
    function getSpentToday(address token) external returns (uint256);
}
