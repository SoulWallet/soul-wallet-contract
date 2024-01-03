// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

interface IUpgrade {
    event Upgrade(address indexed newLogic, address indexed oldLogic);

    function upgrade(address wallet) external;
}
