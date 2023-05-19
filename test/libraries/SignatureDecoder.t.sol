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
        bytes memory sig = abi.encodePacked(v, r, s);
        assertEq(sig.length, 65);
        signTypeDecode(sig, sig, 0);
    }

    function signTypeBTest(uint48 validUntil, uint48 validAfter, bytes calldata sig) public {
        // e.g. sig:0x1c75aa92441aa5232a0e40c1bef20c76345308d6b844a48858f553e0ec04a207c67ebd05b9c7262bdae813dc51cd4ea285a30e4bf7766186f7ab88f910c61caf36
        require(sig.length == 65, "invalid signature length");
        uint256 validationData = (uint256(validUntil) << 160) | (uint256(validAfter) << (160 + 48));
        uint8 signType = 0;
        bytes memory packedSig = abi.encodePacked(signType, validationData, sig);
        signTypeDecode(packedSig, sig, validationData);
    }

    function test_SignTypeB() public {
        (, uint256 ownerKey) = makeAddrAndKey("owner");
        bytes32 hash = keccak256(abi.encodePacked("hello world"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, hash);
        bytes memory sig = abi.encodePacked(v, r, s);
        uint48 validUntil = 0;
        uint48 validAfter = 0;
        uint256 validationData = (uint256(validUntil) << 160) | (uint256(validAfter) << (160 + 48));
        uint8 signType = 0;
        bytes memory packedSig = abi.encodePacked(signType, validationData, sig);
        assertEq(packedSig.length, 65 + 32 + 1);
        signTypeDecode(packedSig, sig, validationData);
    }
}
