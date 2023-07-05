// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

interface IUpgrade {
    event Upgrade(address indexed newLogic, address indexed oldLogic);

    function upgrade(address wallet) external;
}
