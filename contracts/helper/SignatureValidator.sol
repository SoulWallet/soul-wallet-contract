// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../authority/OwnerAuth.sol";
import "../libraries/SignatureDecoder.sol";

abstract contract SignatureValidator is OwnerAuth {
    using ECDSA for bytes32;

    /**
     * @dev pack hash message with `signatureData.validationData`
     */
    function _packSignatureHash(bytes32 hash, SignatureDecoder.SignatureData memory signatureData)
        private
        pure
        returns (bytes32 packedHash)
    {
        if (signatureData.validationData == 0) {
            packedHash = hash;
        } else {
            packedHash = keccak256(abi.encodePacked(hash, signatureData.validationData));
        }
    }

    function _isValidateSignature(bytes32 rawHash, bytes memory rawSignature)
        internal
        view
        returns (uint256 validationData, bool sigValid)
    {
        SignatureDecoder.SignatureData memory signatureData = SignatureDecoder.decodeSignature(rawSignature);
        validationData = signatureData.validationData;
        bytes32 hash = _packSignatureHash(rawHash, signatureData);
        (address recovered, ECDSA.RecoverError error) = ECDSA.tryRecover(hash, signatureData.signature);
        if (error != ECDSA.RecoverError.NoError) {
            sigValid = false;
        } else {
            sigValid = _isOwner(recovered);
        }
    }

    function _isValidUserOp(bytes32 userOpHash, bytes calldata userOpSignature)
        internal
        view
        returns (uint256 validationData, bool sigValid)
    {
        SignatureDecoder.SignatureData memory signatureData = SignatureDecoder.decodeSignature(userOpSignature);
        validationData = signatureData.validationData;
        bytes32 hash = _packSignatureHash(userOpHash, signatureData).toEthSignedMessageHash();
        (address recovered, ECDSA.RecoverError error) = ECDSA.tryRecover(hash, signatureData.signature);
        if (error != ECDSA.RecoverError.NoError) {
            sigValid = false;
        } else {
            sigValid = _isOwner(recovered);
        }
    }
}
