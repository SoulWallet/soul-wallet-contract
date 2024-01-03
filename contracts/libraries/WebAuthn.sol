
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Base64Url} from "./Base64Url.sol";
import {FCL_Elliptic_ZZ} from "./FCL_elliptic.sol";
import {RS256Verify} from "./RS256Verify.sol";

library WebAuthn {
    /**
     * @dev Prefix for client data
     * defined in:
     * 1. https://www.w3.org/TR/webauthn-2/#dictdef-collectedclientdata
     * 2. https://www.w3.org/TR/webauthn-2/#clientdatajson-serialization
     */
    string private constant ClIENTDATA_PREFIX = "{\"type\":\"webauthn.get\",\"challenge\":\"";

    /**
     * @dev Verify WebAuthN signature
     * @param Qx public key point - x
     * @param Qy public key point - y
     * @param r signature - r
     * @param s signature - s
     * @param challenge https://www.w3.org/TR/webauthn-2/#dom-publickeycredentialcreationoptions-challenge
     * @param authenticatorData https://www.w3.org/TR/webauthn-2/#assertioncreationdata-authenticatordataresult
     * @param clientDataSuffix https://www.w3.org/TR/webauthn-2/#clientdatajson-serialization
     */
    function verifyP256Signature(
        uint256 Qx,
        uint256 Qy,
        uint256 r,
        uint256 s,
        bytes32 challenge,
        bytes memory authenticatorData,
        string memory clientDataSuffix
    ) internal view returns (bool) {
        bytes memory challengeBase64 = bytes(Base64Url.encode(bytes.concat(challenge)));
        bytes memory clientDataJSON = bytes.concat(bytes(ClIENTDATA_PREFIX), challengeBase64, bytes(clientDataSuffix));
        bytes32 clientHash = sha256(clientDataJSON);
        bytes32 message = sha256(bytes.concat(authenticatorData, clientHash));
        return FCL_Elliptic_ZZ.ecdsa_verify(message, r, s, Qx, Qy);
    }

    /**
     * @dev Verify WebAuthN signature
     * @param Qx public key point - x
     * @param Qy public key point - y
     * @param r signature - r
     * @param s signature - s
     * @param challenge https://www.w3.org/TR/webauthn-2/#dom-publickeycredentialcreationoptions-challenge
     * @param authenticatorData https://www.w3.org/TR/webauthn-2/#assertioncreationdata-authenticatordataresult
     * @param clientDataPrefix https://www.w3.org/TR/webauthn-2/#clientdatajson-serialization
     * @param clientDataSuffix https://www.w3.org/TR/webauthn-2/#clientdatajson-serialization
     */
    function verifyP256Signature(
        uint256 Qx,
        uint256 Qy,
        uint256 r,
        uint256 s,
        bytes32 challenge,
        bytes memory authenticatorData,
        string memory clientDataPrefix,
        string memory clientDataSuffix
    ) internal view returns (bool) {
        bytes memory challengeBase64 = bytes(Base64Url.encode(bytes.concat(challenge)));
        bytes memory clientDataJSON = bytes.concat(bytes(clientDataPrefix), challengeBase64, bytes(clientDataSuffix));
        bytes32 clientHash = sha256(clientDataJSON);
        bytes32 message = sha256(bytes.concat(authenticatorData, clientHash));
        return FCL_Elliptic_ZZ.ecdsa_verify(message, r, s, Qx, Qy);
    }

    function decodeP256Signature(bytes calldata packedSignature)
        internal
        pure
        returns (
            uint256 r,
            uint256 s,
            uint8 v,
            bytes calldata authenticatorData,
            bytes calldata clientDataPrefix,
            bytes calldata clientDataSuffix
        )
    {
        /*
            signature layout:
            1. r (32 bytes)
            2. s (32 bytes)
            3. v (1 byte)
            4. authenticatorData length (2 byte max 65535)
            5. clientDataPrefix length (2 byte max 65535)
            6. authenticatorData
            7. clientDataPrefix
            8. clientDataSuffix
            
        */
        uint256 authenticatorDataLength;
        uint256 clientDataPrefixLength;
        assembly ("memory-safe") {
            let calldataOffset := packedSignature.offset
            r := calldataload(calldataOffset)
            s := calldataload(add(calldataOffset, 0x20))
            let lengthData :=
                and(
                    calldataload(add(calldataOffset, 0x25 /* 32+5 */ )),
                    0xffffffffff /* v+authenticatorDataLength+clientDataPrefixLength */
                )
            v := shr(0x20, /* 4*8 */ lengthData)
            authenticatorDataLength := and(shr(0x10, /* 2*8 */ lengthData), 0xffff)
            clientDataPrefixLength := and(lengthData, 0xffff)
        }
        unchecked {
            uint256 _dataOffset1 = 0x45; // 32+32+1+2+2
            uint256 _dataOffset2 = 0x45 + authenticatorDataLength;
            authenticatorData = packedSignature[_dataOffset1:_dataOffset2];

            _dataOffset1 = _dataOffset2 + clientDataPrefixLength;
            clientDataPrefix = packedSignature[_dataOffset2:_dataOffset1];

            clientDataSuffix = packedSignature[_dataOffset1:];
        }
    }

    /**
     * @dev Recover public key from signature
     */
    function recover_p256(bytes32 userOpHash, bytes calldata packedSignature) internal view returns (bytes32) {
        uint256 r;
        uint256 s;
        uint8 v;
        bytes calldata authenticatorData;
        bytes calldata clientDataPrefix;
        bytes calldata clientDataSuffix;
        (r, s, v, authenticatorData, clientDataPrefix, clientDataSuffix) = decodeP256Signature(packedSignature);
        bytes memory challengeBase64 = bytes(Base64Url.encode(bytes.concat(userOpHash)));
        bytes memory clientDataJSON;
        if (clientDataPrefix.length == 0) {
            clientDataJSON = bytes.concat(bytes(ClIENTDATA_PREFIX), challengeBase64, clientDataSuffix);
        } else {
            clientDataJSON = bytes.concat(clientDataPrefix, challengeBase64, clientDataSuffix);
        }
        bytes32 clientHash = sha256(clientDataJSON);
        bytes32 message = sha256(bytes.concat(authenticatorData, clientHash));
        return FCL_Elliptic_ZZ.ec_recover_r1(uint256(message), v, r, s);
    }

    function decodeRS256Signature(bytes calldata packedSignature)
        internal
        pure
        returns (
            bytes calldata n,
            bytes calldata signature,
            bytes calldata authenticatorData,
            bytes calldata clientDataPrefix,
            bytes calldata clientDataSuffix
        )
    {
        /*

            Note: currently use a fixed public exponent=0x010001. This is enough for the currently WebAuthn implementation.
            
            signature layout:
            1. n(exponent) length (2 byte max to 8192 bits key)
            2. authenticatorData length (2 byte max 65535)
            3. clientDataPrefix length (2 byte max 65535)
            4. n(exponent) (exponent,dynamic bytes)
            5. signature (signature,signature.length== n.length)
            6. authenticatorData
            7. clientDataPrefix
            8. clientDataSuffix
            
        */

        uint256 exponentLength;
        uint256 authenticatorDataLength;
        uint256 clientDataPrefixLength;
        assembly ("memory-safe") {
            let calldataOffset := packedSignature.offset
            let lengthData :=
                shr(
                    0xd0, // 8*(32-6), exponentLength+authenticatorDataLength+clientDataPrefixLength
                    calldataload(calldataOffset)
                )
            exponentLength := shr(0x20, /* 4*8 */ lengthData)
            authenticatorDataLength := and(shr(0x10, /* 2*8 */ lengthData), 0xffff)
            clientDataPrefixLength := and(lengthData, 0xffff)
        }
        unchecked {
            uint256 _dataOffset1 = 0x06; // 2+2+2
            uint256 _dataOffset2 = 0x06 + exponentLength;
            n = packedSignature[_dataOffset1:_dataOffset2];

            _dataOffset1 = _dataOffset2 + exponentLength;
            signature = packedSignature[_dataOffset2:_dataOffset1];

            _dataOffset2 = _dataOffset1 + authenticatorDataLength;
            authenticatorData = packedSignature[_dataOffset1:_dataOffset2];

            _dataOffset1 = _dataOffset2 + clientDataPrefixLength;
            clientDataPrefix = packedSignature[_dataOffset2:_dataOffset1];

            clientDataSuffix = packedSignature[_dataOffset1:];
        }
    }

    /**
     * @dev Recover public key from signature
     * in current version, only support e=65537
     */
    function recover_rs256(bytes32 userOpHash, bytes calldata packedSignature) internal view returns (bytes32) {
        bytes calldata n;
        bytes calldata signature;
        bytes calldata authenticatorData;
        bytes calldata clientDataPrefix;
        bytes calldata clientDataSuffix;

        (n, signature, authenticatorData, clientDataPrefix, clientDataSuffix) = decodeRS256Signature(packedSignature);

        bytes memory challengeBase64 = bytes(Base64Url.encode(bytes.concat(userOpHash)));
        bytes memory clientDataJSON;
        if (clientDataPrefix.length == 0) {
            clientDataJSON = bytes.concat(bytes(ClIENTDATA_PREFIX), challengeBase64, clientDataSuffix);
        } else {
            clientDataJSON = bytes.concat(clientDataPrefix, challengeBase64, clientDataSuffix);
        }
        bytes32 clientHash = sha256(clientDataJSON);
        bytes32 messageHash = sha256(bytes.concat(authenticatorData, clientHash));

        // Note: currently use a fixed public exponent=0x010001. This is enough for the currently WebAuthn implementation.
        bytes memory e = hex"0000000000000000000000000000000000000000000000000000000000010001";

        bool success = RS256Verify.RSASSA_PSS_VERIFY(n, e, messageHash, signature);
        if (success) {
            return keccak256(abi.encodePacked(e, n));
        } else {
            return bytes32(0);
        }
    }

    /**
     * @dev Recover public key from signature
     * currently support: ES256(P256), RS256(e=65537)
     */
    function recover(bytes32 hash, bytes calldata signature) internal view returns (bytes32) {
        /*
            signature layout:
            1. algorithmType (1 bytes)
            2. signature

            algorithmType:
            0x0: ES256(P256)
            0x1: RS256(e=65537)
        */
        uint8 algorithmType = uint8(signature[0]);
        if (algorithmType == 0x0) {
            return recover_p256(hash, signature[1:]);
        } else if (algorithmType == 0x1) {
            return recover_rs256(hash, signature[1:]);
        } else {
            revert("invalid algorithm type");
        }
    }
}
