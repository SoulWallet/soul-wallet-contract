// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./IPluggable.sol";

interface IModule is IPluggable {
    function requiredFunctions() external pure returns (bytes4[] memory);
}
