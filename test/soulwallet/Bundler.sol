// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@account-abstraction/contracts/core/EntryPoint.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "@account-abstraction/contracts/interfaces/UserOperation.sol";
import "@source/libraries/DecodeCalldata.sol";

contract Bundler {
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
    function post(IEntryPoint entryPoint, UserOperation memory userOp) external {
        // staticcall: function simulateValidation(UserOperation calldata userOp) external
        if (false) {
            (bool success, bytes memory data) = address(entryPoint).staticcall(
                abi.encodeWithSignature(
                    "simulateValidation((address,uint256,bytes,bytes,uint256,uint256,uint256,uint256,uint256,bytes,bytes))",
                    userOp
                )
            );
            if (!success) {
                bytes4 methodId = DecodeCalldata.decodeMethodId(data);
                if (methodId == IEntryPoint.FailedOp.selector) {
                    // error FailedOp(uint256 opIndex, string reason);
                    bytes memory _data = DecodeCalldata.decodeMethodCalldata(data);
                    (, string memory reason) = abi.decode(_data, (uint256, string));
                    revert(reason);
                } else if (methodId == IEntryPoint.ValidationResult.selector) {
                    // error ValidationResult(ReturnInfo returnInfo, StakeInfo senderInfo, StakeInfo factoryInfo, StakeInfo paymasterInfo);
                } else {
                    console.logBytes(data);
                    revert("simulateValidation failed");
                }
            } else {
                revert("failed");
            }
        }

        UserOperation[] memory userOperations = new UserOperation[](1);
        userOperations[0] = userOp;
        address payable beneficiary = payable(address(0x111));
        entryPoint.handleOps(userOperations, beneficiary);
    }
}
