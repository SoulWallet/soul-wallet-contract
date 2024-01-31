// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";

library UserOperationHelper {
    function packAccountGasLimit(uint256 validationGasLimit, uint256 callGasLimit) internal pure returns (bytes32) {
        return bytes32((validationGasLimit << 128) | callGasLimit);
    }

    function packPaymasterStaticFields(
        address paymaster,
        uint256 validationGasLimit,
        uint256 postOp,
        bytes memory paymasterData
    ) internal pure returns (bytes memory paymasterAndData) {
        bytes32 _gas = bytes32((validationGasLimit << 128) | postOp);
        return abi.encodePacked(paymaster, _gas, paymasterData);
    }

    function newUserOp(
        address sender,
        uint256 nonce,
        bytes memory initCode,
        bytes memory callData,
        uint256 verificationGasLimit,
        uint256 callGasLimit,
        uint256 preVerificationGas,
        uint256 maxFeePerGas,
        uint256 maxPriorityFeePerGas,
        bytes memory paymasterAndData
    ) internal pure returns (PackedUserOperation memory) {
        bytes memory signature;
        PackedUserOperation memory userOperation = PackedUserOperation(
            sender,
            nonce,
            initCode,
            callData,
            packAccountGasLimit(verificationGasLimit, callGasLimit),
            preVerificationGas,
            packAccountGasLimit(maxPriorityFeePerGas, maxFeePerGas),
            paymasterAndData,
            signature
        );
        return userOperation;
    }

    function unpackAccountGasLimits(bytes32 accountGasLimits)
        internal
        pure
        returns (uint256 validationGasLimit, uint256 callGasLimit)
    {
        return (uint128(bytes16(accountGasLimits)), uint128(uint256(accountGasLimits)));
    }

    function unpackPaymasterStaticFields(bytes memory paymasterAndData)
        internal
        pure
        returns (address paymaster, uint256 validationGasLimit, uint256 postOp)
    {
        assembly {
            // paymaster: paymasterAndData[:20]
            paymaster := shr(96, mload(add(paymasterAndData, 0x20)))
            // validationGasLimit: paymasterAndData[20:36]
            validationGasLimit := shr(128, mload(add(paymasterAndData, add(0x20, 20))))
            // postOp: paymasterAndData[36:52]
            postOp := and(0xffffffffffffffffffffffffffffffff, mload(add(paymasterAndData, add(0x20, 20))))
        }
    }

    function getRequiredPrefund(PackedUserOperation memory mUserOp) internal pure returns (uint256 requiredPrefund) {
        (uint256 verificationGasLimit, uint256 callGasLimit) = unpackAccountGasLimits(mUserOp.accountGasLimits);
        uint256 paymasterVerificationGasLimit = 0;
        uint256 paymasterPostOpGasLimit = 0;
        if (mUserOp.paymasterAndData.length > 0) {
            require(mUserOp.paymasterAndData.length >= 52, "AA93 invalid paymasterAndData");
            (, paymasterVerificationGasLimit, paymasterPostOpGasLimit) =
                unpackPaymasterStaticFields(mUserOp.paymasterAndData);
        }
        unchecked {
            uint256 requiredGas = verificationGasLimit + callGasLimit + paymasterVerificationGasLimit
                + paymasterPostOpGasLimit + mUserOp.preVerificationGas;
            (, uint256 maxFeePerGas) = unpackAccountGasLimits(mUserOp.gasFees);
            requiredPrefund = requiredGas * maxFeePerGas;
        }
    }
}
