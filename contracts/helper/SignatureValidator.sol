// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../authority/OwnerAuth.sol";
import "../libraries/SignatureDecoder.sol";
import "../libraries/Errors.sol";

abstract contract SignatureValidator is OwnerAuth {
    using ECDSA for bytes32;

    /**
     * @dev pack hash message with `signatureData.validationData`
     */
    function _packSignatureHash(bytes32 hash, uint8 signType, uint256 validationData)
        private
        pure
        returns (bytes32 packedHash)
    {
        if (signType == 0) {
            packedHash = hash;
        } else if (signType == 1) {
            packedHash = keccak256(abi.encodePacked(hash, validationData));
        } else {
            revert Errors.INVALID_SIGNTYPE();
        }
    }

    function _isValidateSignature(bytes32 rawHash, bytes calldata rawSignature)
        internal
        view
        returns (uint256 validationData, bool sigValid)
    {
        uint8 signType;
        bytes calldata signature;
        bytes calldata guardHookInputData;
        (signType, signature, validationData, guardHookInputData) = SignatureDecoder.decodeSignature(rawSignature);

        bytes32 hash = _packSignatureHash(rawHash, signType, validationData).toEthSignedMessageHash();
        (address recovered, ECDSA.RecoverError error) = ECDSA.tryRecover(hash, signature);
        if (error != ECDSA.RecoverError.NoError) {
            sigValid = false;
        } else {
            sigValid = _isOwner(recovered);
        }
    }

    function _isValidUserOp(bytes32 userOpHash, bytes calldata userOpSignature)
        internal
        view
        returns (uint256 validationData, bool sigValid, bytes calldata guardHookInputData)
    {
        uint8 signType;
        bytes calldata signature;
        (signType, signature, validationData, guardHookInputData) = SignatureDecoder.decodeSignature(userOpSignature);
        bytes32 hash = _packSignatureHash(userOpHash, signType, validationData).toEthSignedMessageHash();
        (address recovered, ECDSA.RecoverError error) = ECDSA.tryRecover(hash, signature);
        if (error != ECDSA.RecoverError.NoError) {
            sigValid = false;
        } else {
            sigValid = _isOwner(recovered);
        }
    }
}
