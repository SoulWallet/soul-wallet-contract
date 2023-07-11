// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

interface IL1Block {
    function hash() external returns (bytes32);
    function number() external returns (uint256);
}
