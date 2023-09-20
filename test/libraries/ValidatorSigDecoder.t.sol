// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@source/validator/libraries/ValidatorSigDecoder.sol";

contract ValidatorSigDecoderTest is Test {
    function validatorSignTypeDecode(
        bytes calldata signature,
        bytes memory assertSign,
        uint8 assertSignType,
        uint256 assertValidationData
    ) external {
        (uint8 signatureType, uint256 validationData, bytes calldata _signature) =
            ValidatorSigDecoder.decodeValidatorSignature(signature);
        assertEq(_signature, assertSign);
        assertEq(validationData, assertValidationData);
        assertEq(signatureType, assertSignType);
    }

    /*
    validator signature format
    +----------------------------------------------------------+
    |                                                          |
    |             validator signature                          |
    |                                                          |
    +-------------------------------+--------------------------+
    |         signature type        |       signature data     |
    +-------------------------------+--------------------------+
    |                               |                          |
    |            1 byte             |          ......          |
    |                               |                          |
    +-------------------------------+--------------------------+

    

    A: signature type 0: eoa sig without validation data

    +------------------------------------------------------------------------+
    |                                                                        |
    |                             validator signature                        |
    |                                                                        |
    +--------------------------+----------------------------------------------+
    |       signature type     |                signature data                |
    +--------------------------+----------------------------------------------+
    |                          |                                              |
    |           0x00           |                    65 bytes                  |
    |                          |                                              |
    +--------------------------+----------------------------------------------+
    */
    function test_SignValidatorTypeA() public {
        (, uint256 ownerKey) = makeAddrAndKey("owner");
        bytes32 hash = keccak256(abi.encodePacked("hello world"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, hash);
        bytes memory sig = abi.encodePacked(r, s, v);
        assertEq(sig.length, 65);
        uint8 signType = 0;
        bytes memory validatorSignature = abi.encodePacked(signType, sig);
        (bool succ,) = address(this).call(
            abi.encodeWithSelector(this.validatorSignTypeDecode.selector, validatorSignature, sig, 0, 0)
        );
        require(succ, "failed");
    }
    /*
    B: signature type 1: eoa sig with validation data

    +-------------------------------------------------------------------------------------+
    |                                                                                     |
    |                                        validator signature                          |
    |                                                                                     |
    +-------------------------------+--------------------------+---------------------------+
    |         signature type        |      validationData      |       signature data      |
    +-------------------------------+--------------------------+---------------------------+
    |                               |                          |                           |
    |            0x01               |     uint256 32 bytes     |           65 bytes        |
    |                               |                          |                           |
    +-------------------------------+--------------------------+---------------------------+
    */

    function test_SignValidatorTypeB() public {
        (, uint256 ownerKey) = makeAddrAndKey("owner");
        bytes32 hash = keccak256(abi.encodePacked("hello world"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, hash);
        bytes memory sig = abi.encodePacked(r, s, v);
        assertEq(sig.length, 65);
        uint8 signType = 1;
        uint48 validUntil = 0;
        uint48 validAfter = 1695199125;
        uint256 validationData = (uint256(validUntil) << 160) | (uint256(validAfter) << (160 + 48));
        bytes memory validatorSignature = abi.encodePacked(signType, validationData, sig);
        (bool succ,) = address(this).call(
            abi.encodeWithSelector(this.validatorSignTypeDecode.selector, validatorSignature, sig, 1, validationData)
        );
        require(succ, "failed");
    }
}
