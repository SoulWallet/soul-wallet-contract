// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@source/libraries/SignatureDecoder.sol";

contract SignatureDecoderTest is Test {
    function signTypeDecode(bytes memory signature, bytes memory assertSign, uint256 assertValidationData) private {
        SignatureDecoder.SignatureData memory signatureData = SignatureDecoder.decodeSignature(signature);
        assertEq(signatureData.validationData, assertValidationData);
        assertEq(signatureData.signature, assertSign);
    }

    function test_SignTypeA() public {
        (, uint256 ownerKey) = makeAddrAndKey("owner");
        bytes32 hash = keccak256(abi.encodePacked("hello world"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, hash);
        bytes memory sig = abi.encodePacked(r, s, v);
        assertEq(sig.length, 65);
        signTypeDecode(sig, sig, 0);
    }

    function test_SignTypeB() public {
        (, uint256 ownerKey) = makeAddrAndKey("owner");
        bytes32 hash = keccak256(abi.encodePacked("hello world"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, hash);
        bytes memory sig = abi.encodePacked(r, s, v);
        uint48 validUntil = 0;
        uint48 validAfter = 0;
        uint256 validationData = (uint256(validUntil) << 160) | (uint256(validAfter) << (160 + 48));
        uint8 signType = 0;
        bytes memory packedSig = abi.encodePacked(signType, validationData, sig);
        assertEq(packedSig.length, 65 + 32 + 1);
        signTypeDecode(packedSig, sig, validationData);
    }
}
