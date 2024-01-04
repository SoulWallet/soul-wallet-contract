// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "./DeployHelper.sol";

contract SingletonFactory is Script, DeployHelper {
    function run() public {
        deploySingletonFactory();
    }
}
