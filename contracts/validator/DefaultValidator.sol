// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "./BaseValidator.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
/**
 * @title DefaultValidator
 * @dev Provides default implementations for signature hash packing
 */

contract DefaultValidator is BaseValidator {
    // Utility for Ethereum typed structured data hashing
    using MessageHashUtils for bytes32;
    // Utility for converting addresses to bytes32
    using TypeConversion for address;

    /**
     * @dev Packs the given hash with the specified validation data based on the signature type
     *      - Type 0x0: Standard Ethereum signed message
     *      - Type 0x1: Ethereum signed message combined with validation data
     *      - Type 0x2: Passkey signature (unchanged hash)
     *      - Type 0x3: Passkey signature combined with validation data
     * @param hash The original hash to be packed
     * @param signatureType The type of signature
     * @param validationData same as defined in EIP4337
     * @return packedHash The resulting hash after packing based on signature type
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
    /**
     * @dev Packs the given hash for EIP-1271 compatible signatures. EIP-1271 represents signatures
     *      that are verified by smart contracts themselves.
     *      - Type 0x0: Unchanged hash.
     *      - Type 0x1: Hash combined with validation data
     *      - Type 0x2: Unchanged hash
     *      - Type 0x3: Hash combined with validation data
     * @param hash The original hash to be packed
     * @param signatureType The type of signature
     * @param validationData Additional data used for certain signature types
     * @return packedHash The resulting hash after packing
     */

    function _pack1271SignatureHash(bytes32 hash, uint8 signatureType, uint256 validationData)
        internal
        pure
        override
        returns (bytes32 packedHash)
    {
        if (signatureType == 0x0) {
            packedHash = hash;
        } else if (signatureType == 0x1) {
            packedHash = keccak256(abi.encodePacked(hash, validationData));
        } else if (signatureType == 0x2) {
            packedHash = hash;
        } else if (signatureType == 0x3) {
            packedHash = keccak256(abi.encodePacked(hash, validationData));
        } else {
            revert Errors.INVALID_SIGNTYPE();
        }
    }
}
