// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

interface IDepositManager {
    /**
     * check current account deposit in the entryPoint
     */
    function getDeposit() external view returns (uint256);

    /**
     * deposit more funds for this account in the entryPoint
     */
    function addDeposit() external payable;

    /**
     * withdraw value from the account's deposit
     * @param withdrawAddress target to send to
     * @param amount to withdraw
     */
    function withdrawDepositTo(
        address payable withdrawAddress,
        uint256 amount
    ) external;
}
