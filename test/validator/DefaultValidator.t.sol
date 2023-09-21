// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@source/validator/DefaultValidator.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@source/libraries/TypeConversion.sol";

contract ValidatorSigDecoderTest is Test {
    DefaultValidator defaultValidator;

    using TypeConversion for address;

    using ECDSA for bytes32;

    function setUp() public {
        defaultValidator = new DefaultValidator();
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
    function test_ValidatorRecoverSignatureTypeA() public {
        (address owner, uint256 ownerKey) = makeAddrAndKey("owner");
        bytes32 hash = keccak256(abi.encodePacked("hello world"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, hash.toEthSignedMessageHash());
        bytes memory sig = abi.encodePacked(r, s, v);
        assertEq(sig.length, 65);
        uint8 signType = 0;
        bytes memory validatorSignature = abi.encodePacked(signType, sig);
        (uint256 _valdatioData, bytes32 recovered, bool success) =
            defaultValidator.recoverSignature(hash, validatorSignature);
        assertEq(_valdatioData, 0);
        assertEq(recovered, owner.toBytes32());
        assertEq(success, true);
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

    function test_ValidatorRecoverSignatureTypeB() public {
        (address owner, uint256 ownerKey) = makeAddrAndKey("owner");
        bytes32 hash = keccak256(abi.encodePacked("hello world"));
        uint48 validUntil = 0;
        uint48 validAfter = 1695199125;
        uint256 validationData = (uint256(validUntil) << 160) | (uint256(validAfter) << (160 + 48));
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(ownerKey, keccak256(abi.encodePacked(hash, validationData)).toEthSignedMessageHash());
        bytes memory sig = abi.encodePacked(r, s, v);
        assertEq(sig.length, 65);
        uint8 signType = 1;

        bytes memory validatorSignature = abi.encodePacked(signType, validationData, sig);
        (uint256 _valdatioData, bytes32 recovered, bool success) =
            defaultValidator.recoverSignature(hash, validatorSignature);
        assertEq(_valdatioData, validationData);
        assertEq(recovered, owner.toBytes32());
        assertEq(success, true);
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
        bytes32 hash = 0x83714056da6e6910b51595330c2c2cdfbf718f2deff5bdd84b95df7a7f36f6dd;
        bytes memory authenticatorData = hex"49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97630500000000";
        string memory clientDataSuffix = "\",\"origin\":\"http://localhost:5500\",\"crossOrigin\":false}";
        bytes memory sig = abi.encodePacked(Qx, Qy, r, s, abi.encode(authenticatorData, clientDataSuffix));

        uint8 signType = 0x2;
        bytes memory validatorSignature = abi.encodePacked(signType, sig);
        (uint256 _valdatioData, bytes32 recovered, bool success) =
            defaultValidator.recoverSignature(hash, validatorSignature);
        bytes32 expectRecovered = keccak256(abi.encodePacked(Qx, Qy));
        assertEq(_valdatioData, 0);
        assertEq(recovered, expectRecovered);
        assertEq(success, true);
    }
}
