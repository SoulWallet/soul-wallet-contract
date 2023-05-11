// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../authority/OwnerAuth.sol";
import "../libraries/SignatureDecoder.sol";
import "../../account-abstraction/contracts/core/BaseAccount.sol";

abstract contract SignatureValidator is OwnerAuth, BaseAccount {
    using ECDSA for bytes32;

    /**
     * @dev pack hash message with `signatureData.validationData`
     */
    function packSignatureHash(
        bytes32 hash,
        SignatureDecoder.SignatureData memory signatureData
    ) private pure returns (bytes32 packedHash) {
        if (signatureData.validationData == 0) {
            packedHash = hash;
        } else {
            packedHash = keccak256(abi.encodePacked(hash, signatureData.validationData));
        }
    }

    function isValidateSignature(
        bytes32 rawHash,
        bytes memory rawSignature
    ) internal view returns (uint256 validationData, bool sigValid) {
        SignatureDecoder.SignatureData memory signatureData = SignatureDecoder.decodeSignature(rawSignature);
        validationData = signatureData.validationData;
        bytes32 hash = packSignatureHash(rawHash, signatureData);
        (address recovered, ECDSA.RecoverError error) = ECDSA.tryRecover(hash, signatureData.signature);
        if (error != ECDSA.RecoverError.NoError) {
            sigValid = false;
        } else {
            sigValid = _isOwner(recovered);
        }
    }

    function _isValidateSignature(
        bytes32 rawHash,
        bytes memory rawSignature
    ) internal view returns (uint256 validationData, bool sigValid) {
        SignatureDecoder.SignatureData memory signatureData = SignatureDecoder.decodeSignature(rawSignature);
        validationData = signatureData.validationData;
        bytes32 hash = packSignatureHash(rawHash, signatureData).toEthSignedMessageHash();
        (address recovered, ECDSA.RecoverError error) = ECDSA.tryRecover(hash, signatureData.signature);
        if (error != ECDSA.RecoverError.NoError) {
            sigValid = false;
        } else {
            sigValid = _isOwner(recovered);
        }
    }

    function isValidUserOpSignature(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) internal view returns (uint256 validationData) {
        bool sigValid;
        (validationData, sigValid) = _isValidateSignature(userOpHash, userOp.signature);
        // equivalence code: `(sigFailed ? 1 : 0) | (uint256(validUntil) << 160) | (uint256(validAfter) << (160 + 48))`
        // validUntil and validAfter is already packed in signatureData.validationData,
        // and aggregator is address(0), so we just need to add sigFailed flag.
        validationData = validationData | (sigValid ? 0 : SIG_VALIDATION_FAILED);
    }
}
