// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
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
        string memory challengeBase64 = Base64.encode(bytes.concat(challenge));
        string memory clientDataJSON = string.concat(ClIENTDATA_PREFIX, challengeBase64, clientDataSuffix);
        bytes32 clientHash = sha256(bytes(clientDataJSON));
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
        string memory challengeBase64 = Base64.encode(bytes.concat(challenge));
        string memory clientDataJSON = string.concat(clientDataPrefix, challengeBase64, clientDataSuffix);
        bytes32 clientHash = sha256(bytes(clientDataJSON));
        bytes32 message = sha256(bytes.concat(authenticatorData, clientHash));
        return FCL_Elliptic_ZZ.ecdsa_verify(message, r, s, Qx, Qy);
    }
}
