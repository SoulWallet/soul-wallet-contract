// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../interfaces/IValidator.sol";
import "./libraries/ValidatorSigDecoder.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../libraries/TypeConversion.sol";
import "../libraries/Errors.sol";
import "../libraries/WebAuthn.sol";

abstract contract BaseValidator is IValidator {
    using ECDSA for bytes32;
    using TypeConversion for address;

    function _packSignatureHash(bytes32 hash, uint8 signatureType, uint256 validationData)
        internal
        pure
        virtual
        returns (bytes32);

    function recover(uint8 signatureType, bytes32 rawHash, bytes calldata rawSignature)
        internal
        view
        returns (bytes32 recovered, bool success)
    {
        if (signatureType == 0x0 || signatureType == 0x1) {
            //ecdas recover
            (address recoveredAddr, ECDSA.RecoverError error) = ECDSA.tryRecover(rawHash, rawSignature);
            if (error != ECDSA.RecoverError.NoError) {
                success = false;
            } else {
                success = true;
            }
            recovered = recoveredAddr.toBytes32();
        } else if (signatureType == 0x2 || signatureType == 0x3) {
            uint256 Qx = uint256(bytes32(rawSignature[0:32]));
            uint256 Qy = uint256(bytes32(rawSignature[32:64]));
            uint256 r = uint256(bytes32(rawSignature[64:96]));
            uint256 s = uint256(bytes32(rawSignature[96:128]));
            (bytes memory authenticatorData, string memory clientDataSuffix) =
                abi.decode(rawSignature[128:], (bytes, string));
            success = WebAuthn.verifySignature(Qx, Qy, r, s, rawHash, authenticatorData, clientDataSuffix);
            if (success) {
                recovered = keccak256(abi.encodePacked(Qx, Qy));
            } else {
                // notice: if signature is invalid, recovered should be 0?
                recovered = bytes32(0);
            }
        } else {
            revert Errors.INVALID_SIGNTYPE();
        }
    }

    function recoverSignature(bytes32 rawHash, bytes calldata rawSignature)
        external
        view
        override
        returns (uint256 validationData, bytes32 recovered, bool success)
    {
        uint8 signatureType;
        bytes calldata signature;
        (signatureType, validationData, signature) = ValidatorSigDecoder.decodeValidatorSignature(rawSignature);

        bytes32 hash = _packSignatureHash(rawHash, signatureType, validationData);

        (recovered, success) = recover(signatureType, hash, signature);
    }
}
