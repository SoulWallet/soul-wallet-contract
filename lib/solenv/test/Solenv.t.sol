// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Solenv} from "src/Solenv.sol";

contract SolenvTest is Test {
    function setUp() external {
        Solenv.config();
    }

    function _assertDefault() private {
        assertEq(vm.envString("WHY_USE_THIS_KEY"),              "because we can can can");
        assertEq(vm.envString("SOME_VERY_IMPORTANT_API_KEY"),   "omgnoway");
        assertEq(vm.envString("A_COMPLEX_ENV_VARIABLE"),        "y&2U9xiEINv!vM8Gez");
        assertEq(vm.envUint("A_NUMBER"),                        100);
        assertEq(vm.envBool("A_TRUE_BOOL"),                     true);
        assertEq(vm.envBool("A_FALSE_BOOL"),                    false);
        assertEq(vm.envBool("A_FALSE_BOOL"),                    false);
        assertEq(vm.envAddress("AN_ADDRESS"), 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        assertEq(vm.envBytes32("A_BYTES_32"), 0x0000000000000000000000000000000000000000000000000000000000000010);
    }

    function _resetEnv() private {
        vm.setEnv("WHY_USE_THIS_KEY",               "");
        vm.setEnv("SOME_VERY_IMPORTANT_API_KEY",    "");
        vm.setEnv("A_COMPLEX_ENV_VARIABLE",         "");
        vm.setEnv("A_NUMBER",                       "");
        vm.setEnv("A_TRUE_BOOL",                    "");
        vm.setEnv("A_FALSE_BOOL",                   "");
        vm.setEnv("A_FALSE_BOOL",                   "");
        vm.setEnv("AN_ADDRESS",                     "");
        vm.setEnv("A_BYTES_32",                     "");

        assertEq(vm.envString("WHY_USE_THIS_KEY"),              "", "failed to reset");
        assertEq(vm.envString("SOME_VERY_IMPORTANT_API_KEY"),   "", "failed to reset");
        assertEq(vm.envString("A_COMPLEX_ENV_VARIABLE"),        "", "failed to reset");
        assertEq(vm.envString("A_NUMBER"),                      "", "failed to reset");
        assertEq(vm.envString("A_TRUE_BOOL"),                   "", "failed to reset");
        assertEq(vm.envString("A_FALSE_BOOL"),                  "", "failed to reset");
        assertEq(vm.envString("A_FALSE_BOOL"),                  "", "failed to reset");
        assertEq(vm.envString("AN_ADDRESS"),                    "", "failed to reset");
        assertEq(vm.envString("A_BYTES_32"),                    "", "failed to reset");
    }

    function testAll() public {
        // LOAD CONFIG IN SETUP
        _assertDefault();
        _resetEnv();

        // LOAD DEFAULT CONFIG
        Solenv.config();
        _assertDefault();
        _resetEnv();

        // TEST ANOTHER FILENAME
        Solenv.config(".env.test");
        assertEq(vm.envString("SOME_VERY_IMPORTANT_API_KEY"), "adifferentone");
        _resetEnv();

        // TEST MERGE INSTEAD OF OVERWRITE
        // arrange - set some pre-existing env
        vm.setEnv("WHY_USE_THIS_KEY",   "different value");
        vm.setEnv("A_NUMBER",           "1337");
        vm.setEnv("A_TRUE_BOOL",        "false");
        vm.setEnv("A_FALSE_BOOL",       "true");

        // act
        Solenv.config(".env", false);

        // assert
        // from file
        assertEq(vm.envString("SOME_VERY_IMPORTANT_API_KEY"),   "omgnoway");
        assertEq(vm.envString("A_COMPLEX_ENV_VARIABLE"),        "y&2U9xiEINv!vM8Gez");
        assertEq(vm.envAddress("AN_ADDRESS"), 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        assertEq(vm.envBytes32("A_BYTES_32"), 0x0000000000000000000000000000000000000000000000000000000000000010);

        // set manually
        assertEq(vm.envString("WHY_USE_THIS_KEY"),  "different value");
        assertEq(vm.envUint("A_NUMBER"),            1337);
        assertEq(vm.envBool("A_TRUE_BOOL"),         false);
        assertEq(vm.envBool("A_FALSE_BOOL"),        true);

        // cleanup
        _resetEnv();
    }
}
