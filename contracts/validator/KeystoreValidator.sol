// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "./BaseValidator.sol";
/**
 * @title KeystoreValidator
 * @dev Validates signatures based on the Keystore standard
 */

contract KeystoreValidator is BaseValidator {
    using ECDSA for bytes32;
    using TypeConversion for address;

    /**
     * @dev Packs the hash message with `signatureData.validationData`
     * @param hash The hash that needs to be packed with validationData
     * @param signatureType The type of the signature
     * @param validationData The data used for validation as per EIP-4337
     * @return packedHash The resultant packed hash
     */

    function _packSignatureHash(bytes32 hash, uint8 signatureType, uint256 validationData)
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
     * @dev Function for packing 1271 signature hash
     * This implementation always reverts because `KeystoreValidator` doesn't support EIP-1271 signatures
     * @param hash The hash to be packed
     * @param signatureType The type of the signature
     * @param validationData The data used for validation as per EIP-4337
     * @return This function always reverts and never returns
     */

    function _pack1271SignatureHash(bytes32 hash, uint8 signatureType, uint256 validationData)
        internal
        pure
        virtual
        override
        returns (bytes32)
    {
        revert("KeystoreValidator doesn't support 1271");
    }
}
