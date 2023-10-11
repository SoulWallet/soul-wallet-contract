// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

interface IValidator {
    function recoverSignature(bytes32 rawHash, bytes calldata rawSignature)
        external
        view
        returns (uint256 validationData, bytes32 recovered, bool success);
}
