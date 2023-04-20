// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./IFallbackModule.sol";

interface IFallbackModuleManager {
    event FallbackModuleAdded(address module, bytes4[] staticCallMethodId);
    event FallbackModuleRemoved(address module);
    function getFallbackModules() external view returns (address[] memory modules);
    function addFallbackModule(IFallbackModule module, bytes4[] calldata staticCallMethodId) external;
    function removeFallbackModule(address module) external;
}
