// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "./BaseValidator.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract DefaultValidator is BaseValidator {
    using MessageHashUtils for bytes32;
    using TypeConversion for address;

    /**
     * @dev pack hash message with `signatureData.validationData`
     */
    function _packSignatureHash(bytes32 hash, uint8 signatureType, uint256 validationData)
        internal
        pure
        override
        returns (bytes32 packedHash)
    {
        if (signatureType == 0x0) {
            packedHash = hash.toEthSignedMessageHash();
        } else if (signatureType == 0x1) {
            packedHash = keccak256(abi.encodePacked(hash, validationData)).toEthSignedMessageHash();
        } else if (signatureType == 0x2) {
            // passkey sign doesn't need toEthSignedMessageHash
            packedHash = hash;
        } else if (signatureType == 0x3) {
            // passkey sign doesn't need toEthSignedMessageHash
            packedHash = keccak256(abi.encodePacked(hash, validationData));
        } else {
            revert Errors.INVALID_SIGNTYPE();
        }
    }
}
