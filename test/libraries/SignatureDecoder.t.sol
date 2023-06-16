// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@source/libraries/SignatureDecoder.sol";

contract SignatureDecoderTest is Test {
    function signTypeDecode(
        bytes calldata signature,
        bytes memory assertSign,
        uint256 assertValidationData,
        bytes calldata assertGuardHookInputData
    ) external {
        (, bytes calldata _signature, uint256 validationData, bytes calldata guardHookInputData) =
            SignatureDecoder.decodeSignature(signature);
        assertEq(validationData, assertValidationData);
        assertEq(_signature, assertSign);
        assertEq(guardHookInputData, assertGuardHookInputData);
    }

    function test_SignTypeA() public {
        (, uint256 ownerKey) = makeAddrAndKey("owner");
        bytes32 hash = keccak256(abi.encodePacked("hello world"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, hash);
        bytes memory sig = abi.encodePacked(r, s, v);
        assertEq(sig.length, 65);
        bytes memory guardHookInputData;
        (bool succ,) = address(this).call(
            abi.encodeWithSelector(this.signTypeDecode.selector, sig, sig, uint256(0), guardHookInputData)
        );
        require(succ, "failed");
        //signTypeDecode(sig, sig, 0);
    }

    function test_SignTypeB() public {
        (, uint256 ownerKey) = makeAddrAndKey("owner");
        bytes32 hash = keccak256(abi.encodePacked("hello world"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, hash);
        bytes memory sig = abi.encodePacked(r, s, v);
        uint48 validUntil = 0;
        uint48 validAfter = 0;
        uint256 validationData = (uint256(validUntil) << 160) | (uint256(validAfter) << (160 + 48));
        uint8 signType = 1;
        bytes memory packedSig = abi.encodePacked(signType, validationData, sig);
        assertEq(packedSig.length, 65 + 32 + 1);
        bytes memory guardHookInputData;
        (bool succ,) = address(this).call(
            abi.encodeWithSelector(this.signTypeDecode.selector, packedSig, sig, validationData, guardHookInputData)
        );
        require(succ, "failed");
    }

    function test_SignTypeC() public {
        (, uint256 ownerKey) = makeAddrAndKey("owner");
        bytes32 hash = keccak256(abi.encodePacked("hello world"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, hash);
        bytes memory sig = abi.encodePacked(r, s, v);
        uint48 validUntil = 0;
        uint48 validAfter = 0;
        uint256 validationData = (uint256(validUntil) << 160) | (uint256(validAfter) << (160 + 48));
        uint8 signType = 1;
        bytes memory guardHookInputData = abi.encodePacked("guardHookInputData Test");
        bytes memory packedSig = abi.encodePacked(signType, validationData, sig, guardHookInputData);
        assertEq(packedSig.length, 65 + 32 + 1 + guardHookInputData.length);
        // signTypeDecode(packedSig, sig, validationData);
        (bool succ,) = address(this).call(
            abi.encodeWithSelector(this.signTypeDecode.selector, packedSig, sig, validationData, guardHookInputData)
        );
        require(succ, "failed");
    }
}
