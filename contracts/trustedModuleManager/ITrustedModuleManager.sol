// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

interface ITrustedModuleManager {
    function isTrustedModule(address module) external view returns (bool);
    // function addTrustedModule(address[] memory modules) external;
    // function removeTrustedModule(address[] memory modules) external;
}
