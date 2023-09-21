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
            abi.encodeWithSelector(this.validatorSignTypeDecode.selector, validatorSignature, sig, signType, 0)
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
            abi.encodeWithSelector(
                this.validatorSignTypeDecode.selector, validatorSignature, sig, signType, validationData
            )
        );
        require(succ, "failed");
    }
    /*
      
    C: signature type 2: passkey sig without validation data
    +----------------------------------------------------------------------------------------------------------------+
    |                                                                                                                |
    |                                     validator singature                                                        |
    |                                                                                                                |
    +-------------------+--------------------------------------------------------------------------------------------+
    |                   |                                                                                            |
    |   signature type  |                            signature data                                                  |
    |                   |                                                                                            |
    +------------------------------+-----------+-----------+----------+------------+---------+-------+---------------+
    |                   |          |           |           |          |                        |                     |
    |                   |   Qx     |    Qy     |    r      |    s     | authenticatorData      |   clientDataSuffix  |
    +----------------------------------------------------------------------------------------------------------------+
    |                   |          |           |           |          |                        |                     |
    |     0x2           | uint256  |   uint256 |   uint256 | uint256  |                        |                     |
    |                   |          |           |           |          |                        |                     |
    |                   | 32 bytes |  32 bytes |   32 bytes|  32 bytes|     bytes              |       string        |
    |                   |          |           |           |          |                        |                     |
    +-------------------+----------+-----------+-----------+----------+------------+---------+-------+---------------+
    */

    function test_SignValidatorTypeC() public {
        uint256 Qx = uint256(0xe89e8b4be943fadb4dc599fe2e8af87a79b438adde328a3b72d43324506cd5b6);
        uint256 Qy = uint256(0x4fbfe4a2f9934783c3b1af712ee87abc08f576e79346efc3b8355d931bd7b976);
        uint256 r = uint256(0x2ae3ddfe4cc414dc0fad7ff3a5c960d1cee1211722d3099ade76e5ac1826731a);
        uint256 s = uint256(0x87e5d654f357e4cd6cb52512b2da4d91eae0ae48e9d892ce532b9352f63a55d6);
        bytes memory authenticatorData = hex"49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97630500000000";
        string memory clientDataSuffix = "\",\"origin\":\"http://localhost:5500\",\"crossOrigin\":false}";
        bytes memory sig = abi.encodePacked(Qx, Qy, r, s, abi.encode(authenticatorData, clientDataSuffix));

        uint8 signType = 0x2;
        bytes memory validatorSignature = abi.encodePacked(signType, sig);
        (bool succ,) = address(this).call(
            abi.encodeWithSelector(this.validatorSignTypeDecode.selector, validatorSignature, sig, signType, 0)
        );
        require(succ, "failed");
    }
    /*
    D: signature type 3: passkey sig without validation data
    +-----------------------------------------------------------------------------------------------------------------------------------+
    |                                                                                                                                   |
    |                                                        validator singature                                                        |
    |                                                                                                                                   |
    +-----------------+--------------------+--------------------------------------------------------------------------------------------+
    |                 |                    |                                                                                            |
    |   sig type      |  validation data   |                            signature data                                                  |
    |                 |                    |                                                                                            |
    +-------------------------------------------------+-----------+-----------+----------+------------+---------+-------+---------------+
    |                 |                    |          |           |           |          |                      |                       |
    |                 |                    |   Qx     |    Qy     |    r      |    s     |  authenticatorData   |      clientDataSuffix |
    +-----------------------------------------------------------------------------------------------------------------------------------+
    |                 |                    |          |           |           |          |                      |                       |
    |                 |                    | uint256  |   uint256 |   uint256 | uint256  |                      |                       |
    |    0x3          |  uint256 32 bytes  |          |           |           |          |                      |                       |
    |                 |                    | 32 bytes |  32 bytes |   32 bytes|  32 bytes|      bytes           |      string           |
    |                 |                    |          |           |           |          |                      |                       |
    +-----------------+--------------------+----------+-----------+-----------+----------+------------+---------+-------+---------------+

    */

    function test_SignValidatorTypeD() public {
        uint256 Qx = uint256(0xe89e8b4be943fadb4dc599fe2e8af87a79b438adde328a3b72d43324506cd5b6);
        uint256 Qy = uint256(0x4fbfe4a2f9934783c3b1af712ee87abc08f576e79346efc3b8355d931bd7b976);
        uint256 r = uint256(0x2ae3ddfe4cc414dc0fad7ff3a5c960d1cee1211722d3099ade76e5ac1826731a);
        uint256 s = uint256(0x87e5d654f357e4cd6cb52512b2da4d91eae0ae48e9d892ce532b9352f63a55d6);
        bytes memory authenticatorData = hex"49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97630500000000";
        string memory clientDataSuffix = "\",\"origin\":\"http://localhost:5500\",\"crossOrigin\":false}";
        bytes memory sig = abi.encodePacked(Qx, Qy, r, s, abi.encode(authenticatorData, clientDataSuffix));

        uint8 signType = 0x3;
        uint48 validUntil = 0;
        uint48 validAfter = 1695199125;
        uint256 validationData = (uint256(validUntil) << 160) | (uint256(validAfter) << (160 + 48));
        bytes memory validatorSignature = abi.encodePacked(signType, validationData, sig);
        (bool succ,) = address(this).call(
            abi.encodeWithSelector(
                this.validatorSignTypeDecode.selector, validatorSignature, sig, signType, validationData
            )
        );
        require(succ, "failed");
    }
}
