// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

interface IValidator {
    function recoverSignature(bytes32 rawHash, bytes calldata rawSignature)
        external
        pure
        returns (uint256 validationData, bytes32 recovered, bool success);
}
