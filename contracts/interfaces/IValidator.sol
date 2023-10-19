// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

interface IValidator {
    function recoverSignature(bytes32 rawHash, bytes calldata rawSignature)
        external
        view
        returns (uint256 validationData, bytes32 recovered, bool success);
    function recover1271Signature(bytes32 rawHash, bytes calldata rawSignature)
        external
        view
        returns (uint256 validationData, bytes32 recovered, bool success);

    function encodeRawHash(bytes32 rawHash) external view returns (bytes32);
}
