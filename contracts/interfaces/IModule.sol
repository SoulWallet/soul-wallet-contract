// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

interface IModule {
    function init() external;
    function deinit() external;
    function allowedMethods() external returns (bytes4[] memory);
}