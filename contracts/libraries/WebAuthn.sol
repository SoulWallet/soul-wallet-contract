// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Base64Url} from "./Base64Url.sol";
import {FCL_Elliptic_ZZ} from "./FCL_elliptic.sol";

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
    function verifySignature(
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
    function verifySignature(
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

    function decodeSignature(bytes calldata signature)
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
            let calldataOffset := signature.offset
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
            authenticatorData = signature[_dataOffset1:_dataOffset2];

            _dataOffset1 = _dataOffset2 + clientDataPrefixLength;
            clientDataPrefix = signature[_dataOffset2:_dataOffset1];

            clientDataSuffix = signature[_dataOffset1:];
        }
    }

    /**
     * @dev Recover P256 hashed public key from signature
     */
    function recover(bytes32 hash, bytes calldata signature) internal view returns (bytes32) {
        uint256 r;
        uint256 s;
        uint8 v;
        bytes calldata authenticatorData;
        bytes calldata clientDataPrefix;
        bytes calldata clientDataSuffix;
        (r, s, v, authenticatorData, clientDataPrefix, clientDataSuffix) = decodeSignature(signature);
        bytes memory challengeBase64 = bytes(Base64Url.encode(bytes.concat(hash)));
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
}
