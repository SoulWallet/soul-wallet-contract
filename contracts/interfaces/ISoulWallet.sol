// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;


interface ISoulWallet {
    function addOwner(address[] calldata addrs) external;
    function removeOwner(address[] calldata addrs) external;
    function resetOwner(address[] calldata addrs) external;

    function execute(address dest, uint256 value, bytes calldata func) external;
    function executeBatch(address[] calldata dest,
        uint256[] calldata value, bytes calldata func) external;
    function delegateCall(address dest, uint256 value, bytes calldata func) external;

    function addPlugin() external;
    function removePlugin() external;

    function addModule() external;
    function removeModule() external;
}
