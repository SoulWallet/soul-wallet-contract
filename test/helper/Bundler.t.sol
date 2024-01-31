// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import "@source/libraries/DecodeCalldata.sol";

contract Bundler is Test {
    /* 
        address sender;
        uint256 nonce;
        bytes initCode;
        bytes callData;
        uint256 callGasLimit;
        uint256 verificationGasLimit;
        uint256 preVerificationGas;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        bytes paymasterAndData;
        bytes signature;
     */
    function post(IEntryPoint entryPoint, PackedUserOperation memory userOp) external {
        PackedUserOperation[] memory userOperations = new PackedUserOperation[](1);
        userOperations[0] = userOp;
        address payable beneficiary = payable(address(0x111));
        uint256 gas_before = gasleft();
        entryPoint.handleOps(userOperations, beneficiary);
        uint256 gas_after = gasleft();
        console.log("entryPoint.handleOps => gas:", gas_before - gas_after);
    }
}
