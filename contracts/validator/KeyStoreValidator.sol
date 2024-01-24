// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../keystore/L1/interfaces/IKeyStoreValidator.sol";
import "./libraries/ValidatorSigDecoder.sol";
import "../libraries/WebAuthn.sol";
import "../libraries/Errors.sol";
import "../libraries/TypeConversion.sol";

contract KeyStoreValidator is IKeyStoreValidator {
    using TypeConversion for address;

    function recoverSignature(bytes32 rawHash, bytes calldata rawSignature)
        external
        view
        returns (bytes32 recovered, bool success)
    {
        uint8 signatureType;
        bytes calldata signature;
        uint256 validationData;
        (signatureType,, signature) = ValidatorSigDecoder.decodeValidatorSignature(rawSignature);

        (recovered, success) = recover(signatureType, rawHash, signature);
    }

    function recover(uint8 signatureType, bytes32 rawHash, bytes calldata rawSignature)
        internal
        view
        returns (bytes32 recovered, bool success)
    {
        if (signatureType == 0x0 || signatureType == 0x1) {
            //ecdas recover
            (address recoveredAddr, ECDSA.RecoverError error,) = ECDSA.tryRecover(rawHash, rawSignature);
            if (error != ECDSA.RecoverError.NoError) {
                success = false;
            } else {
                success = true;
            }
            recovered = recoveredAddr.toBytes32();
        } else if (signatureType == 0x2 || signatureType == 0x3) {
            bytes32 publicKey = WebAuthn.recover(rawHash, rawSignature);
            if (publicKey == 0) {
                recovered = publicKey;
                success = false;
            } else {
                recovered = publicKey;
                success = true;
            }
        } else {
            revert Errors.INVALID_SIGNTYPE();
        }
    }
}
