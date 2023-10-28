// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title Validator Interface
 * @dev This interface defines the functionalities for signature validation and hash encoding
 */
interface IValidator {
    /**
     * @dev Recover the signer of a given raw hash using the provided raw signature
     * @param rawHash The raw hash that was signed
     * @param rawSignature The signature data
     * @return validationData same as defined in EIP4337
     * @return recovered The recovered signer's signing key from the signature
     * @return success A boolean indicating the success of the recovery
     */
    function recoverSignature(bytes32 rawHash, bytes calldata rawSignature)
        external
        view
        returns (uint256 validationData, bytes32 recovered, bool success);

    /**
     * @dev Recover the signer of a given raw hash using the provided raw signature according to EIP-1271 standards
     * @param rawHash The raw hash that was signed
     * @param rawSignature The signature data
     * @return validationData same as defined in EIP4337
     * @return recovered  The recovered signer's signing key from the signature
     * @return success A boolean indicating the success of the recovery
     */
    function recover1271Signature(bytes32 rawHash, bytes calldata rawSignature)
        external
        view
        returns (uint256 validationData, bytes32 recovered, bool success);

    /**
     * @dev Encode a raw hash to prevent replay attacks
     * @param rawHash The raw hash to encode
     * @return The encoded hash
     */
    function encodeRawHash(bytes32 rawHash) external view returns (bytes32);
}
