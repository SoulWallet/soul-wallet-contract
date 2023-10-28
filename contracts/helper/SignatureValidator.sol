// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../authority/OwnerAuth.sol";
import "../base/Validator.sol";
import "../libraries/Errors.sol";
import "../libraries/TypeConversion.sol";
import "../libraries/SignatureDecoder.sol";

/**
 * @title SignatureValidator
 * @dev This contract provides functionality for validating cryptographic signatures
 */
abstract contract SignatureValidator is OwnerAuth, Validator {
    using ECDSA for bytes32;
    using TypeConversion for address;
    /**
     * @dev Encodes the raw hash using a validator to prevent replay attacks
     * If the same owner signs the message for different smart contract accounts,
     * this function uses EIP-712-like encoding to encode the raw hash
     * @param rawHash The raw hash to encode
     * @return encodeRawHash The encoded hash
     */

    function _encodeRawHash(bytes32 rawHash) internal view returns (bytes32 encodeRawHash) {
        return validator().encodeRawHash(rawHash);
    }
    /**
     * @dev Validates an EIP1271 signature
     * @param rawHash The raw hash against which the signature is to be checked
     * @param rawSignature The signature to validate
     * @return validationData The data used for validation
     * @return sigValid A boolean indicating if the signature is valid or not
     */

    function _isValidate1271Signature(bytes32 rawHash, bytes calldata rawSignature)
        internal
        view
        returns (uint256 validationData, bool sigValid)
    {
        bytes32 recovered;
        bool success;
        bytes calldata guardHookInputData;
        bytes calldata validatorSignature;

        (guardHookInputData, validatorSignature) = SignatureDecoder.decodeSignature(rawSignature);

        // To prevent potential attacks, prohibit the use of guardHookInputData with EIP1271 signatures.
        require(guardHookInputData.length == 0);

        (validationData, recovered, success) = validator().recover1271Signature(rawHash, validatorSignature);

        if (!success) {
            sigValid = false;
        } else {
            sigValid = _isOwner(recovered);
        }
    }
    /**
     * @dev Validates a user operation signature
     * @param userOpHash The hash of the user operation
     * @param userOpSignature The signature of the user operation
     * @return validationData same as defined in EIP4337
     * @return sigValid A boolean indicating if the signature is valid or not
     * @return guardHookInputData Input data for the guard hook
     */

    function _isValidUserOp(bytes32 userOpHash, bytes calldata userOpSignature)
        internal
        view
        returns (uint256 validationData, bool sigValid, bytes calldata guardHookInputData)
    {
        bytes32 recovered;
        bool success;
        bytes calldata validatorSignature;

        (guardHookInputData, validatorSignature) = SignatureDecoder.decodeSignature(userOpSignature);

        (validationData, recovered, success) = validator().recoverSignature(userOpHash, validatorSignature);
        if (!success) {
            sigValid = false;
        } else {
            sigValid = _isOwner(recovered);
        }
    }
}
