// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Solenv} from "src/Solenv.sol";

contract SolenvScript is Script {
    function setUp() public {
        Solenv.config();
    }

    function run() public {
        console.log('reading environment variable "WHY_USE_THIS_KEY"');
        console.log(vm.envString("WHY_USE_THIS_KEY"));
    }
}
