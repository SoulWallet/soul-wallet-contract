// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../libraries/CallHelper.sol";

interface IModuleManager {
    event ModuleAdded(address indexed module, bytes4[] selectors);
    event ModuleRemoved(address indexed module);

    function addModule(address module, bytes4[] calldata selectors) external;

    function removeModule(address module) external;

    function listModule()
        external
        view
        returns (address[] memory modules, bytes4[][] memory selectors);
}
