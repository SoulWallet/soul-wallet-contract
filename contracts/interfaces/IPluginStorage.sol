// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

interface IPluginStorage {
    function pluginDataStore(bytes32 key, bytes calldata value) external;
    function pluginDataLoad(address plugin, bytes32 key) external view returns (bytes memory);
}
