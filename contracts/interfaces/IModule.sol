// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

interface IModule {
    function walletInit(bytes memory data) external;
    function walletDeInit() external;
}