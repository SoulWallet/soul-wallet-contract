// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//return value in case of signature failure, with no time-range.
// equivalent to _packValidationData(true,0,0);
uint256 constant SIG_VALIDATION_FAILED = 1;

uint256 constant SIG_VALIDATION_SUCCESS = 0;
