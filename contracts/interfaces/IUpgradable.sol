// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

interface IUpgradable {
    event Upgraded(address indexed oldImplementation, address indexed newImplementation);

    function upgradeTo(address newImplementation) external;
    function upgradeFrom(address oldImplementation) external;
}
