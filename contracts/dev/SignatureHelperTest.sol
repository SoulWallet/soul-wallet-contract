// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../helpers/SignatureHelper.sol";
import "../entrypoint/Helpers.sol";
import "hardhat/console.sol";

contract SignatureHelperTest {
    using SignatureHelper for bytes;
    using SignatureHelper for uint256;

    constructor() {}

    function decodeSignature(
        bytes memory _bytes
    )
        public
        view
        returns (
            SignatureData memory signatureData,
            ValidationData memory validationData
        )
    {
        signatureData = _bytes.decodeSignature();
        validationData = signatureData.validationData.decodeValidationData();
        console.log("_signer", signatureData.signer);
        console.logUint(uint256(signatureData.mode));
        console.logUint(signatureData.validationData);
        console.logBytes(signatureData.signature);
        console.log("aggregator: %s", validationData.aggregator);
        console.log("validAfter: %s", validationData.validAfter);
        console.log("validUntil: %s", validationData.validUntil);
    }

    function test1(bytes memory _bytes) public view {
        // You must send the following bytes
        // "0x03aaa1111111111111111111111111111111111aaa0000000000010000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003812345678901234567890123456789012345678901234567890abcdef12345678901234567890123456789012345678901234567890abcdef";

        (
            SignatureData memory signatureData,
            ValidationData memory validationData
        ) = decodeSignature(_bytes);
        require(
            signatureData.signer == 0xaaA1111111111111111111111111111111111aaa
        );
        require(signatureData.mode == SignatureMode.guardians);
        require(
            validationData.aggregator ==
                0x0000000000000000000000000000000000000000
        );
        require(validationData.validAfter == 1);
        require(validationData.validUntil == 2);
        // print signatureData.signature you can check the signature is correct
        // true signature:
        // "0x12345678901234567890123456789012345678901234567890abcdef12345678901234567890123456789012345678901234567890abcdef";

        console.log("signatureData.signature:");
        console.logBytes(signatureData.signature);
    }

    function test2(bytes memory _bytes) public view {
        // You must send the following bytes
        // "0x0172963e4Ddb05d2225bE1d337260320a307a97b0cccccccccccccaaaaaaaaaaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000aaaff12345678aabbccdd";
        (
            SignatureData memory signatureData,
            ValidationData memory validationData
        ) = decodeSignature(_bytes);
        require(
            signatureData.signer == 0x72963e4Ddb05d2225bE1d337260320a307a97b0c
        );
        require(signatureData.mode == SignatureMode.owner);
        require(
            validationData.aggregator ==
                0x0000000000000000000000000000000000000000
        );
        require(validationData.validAfter == 0xcccccccccccc);
        require(validationData.validUntil == 0xaaaaaaaaaaaa);
        // print signatureData.signature you can check the signature is correct
        // true signature:
        // "0xaaff12345678aabbccdd";
        console.log("signatureData.signature:");
        console.logBytes(signatureData.signature);
    }

    function test3(bytes memory _bytes) public view {
        // You must send the following bytes
        // "0x0072963e4Ddb05d2225bE1d337260320a307a97b0c000000000000000000000000000000000000000000000000000000000000006000112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff";
        (
            SignatureData memory signatureData,
            ValidationData memory validationData
        ) = decodeSignature(_bytes);
        require(
            signatureData.signer == 0x72963e4Ddb05d2225bE1d337260320a307a97b0c
        );
        require(signatureData.mode == SignatureMode.owner);
        require(
            validationData.aggregator ==
                0x0000000000000000000000000000000000000000
        );
        require(validationData.validAfter == 0);
        require(validationData.validUntil == type(uint48).max);
        // print signatureData.signature you can check the signature is correct
        // true signature:
        // "0x00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff";

        console.log("signatureData.signature:");
        console.logBytes(signatureData.signature);
    }
}
