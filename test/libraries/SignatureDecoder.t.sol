// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@source/libraries/SignatureDecoder.sol";

contract SignatureDecoderTest is Test {
    function signTypeDecode(bytes calldata signature, bytes memory assertSign, bytes calldata assertGuardHookInputData)
        external
    {
        (bytes calldata guardHookInputData, bytes calldata _signature) = SignatureDecoder.decodeSignature(signature);
        assertEq(_signature, assertSign);
        assertEq(guardHookInputData, assertGuardHookInputData);
    }

    /*

    A: data type 0: no plugin data
    +-----------------------------------------------------------------------------------------------------+
    |                                           |                                                         |
    |                                           |                   validator signature                   |
    |                                           |                                                         |
    +---------------+---------------------------+--------------------------+-----------------------------+
    |     data type | data type dynamic data    |     signature type       |       signature data        |
    +---------------+---------------------------+--------------------------+-----------------------------+
    |               |                           |                          |                             |
    |     0x00      |      empty bytes          |        1 byte            |          ......             |
    |               |                           |                          |                             |
    +-----------------------------------------------------------------------------------------------------+
    */
    function test_SignDataTypeA() public {
        (, uint256 ownerKey) = makeAddrAndKey("owner");
        bytes32 hash = keccak256(abi.encodePacked("hello world"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, hash);
        bytes memory sig = abi.encodePacked(r, s, v);
        assertEq(sig.length, 65);
        uint8 signType = 0;
        bytes memory validatorSignature = abi.encodePacked(signType, sig);
        uint8 dataType = 0;
        bytes memory opSig = abi.encodePacked(dataType, validatorSignature);
        bytes memory guardHookInputData;

        (bool succ,) = address(this).call(
            abi.encodeWithSelector(this.signTypeDecode.selector, opSig, validatorSignature, guardHookInputData)
        );
        require(succ, "failed");
        //signTypeDecode(sig, sig, 0);
    }

    /*
     B: data type 1: plugin data

    +-----------------------------------------------------------------------------------------------------+
    |                                           |                                                         |
    |                                           |                   validator signature                   |
    |                                           |                                                         |
    +---------------+---------------------------+--------------------------+-----------------------------+
    |     data type | data type dynamic data    |     signature type       |       signature data        |
    +---------------+---------------------------+--------------------------+-----------------------------+
    |               |                           |                          |                             |
    |     0x01      |      .............        |        1 byte            |          ......             |
    |               |                           |                          |                             |
    +-----------------------------------------------------------------------------------------------------+
    +-------------------------+-------------------------------------+
    |                                                               |
    |                  data type dynamic data                       |
    |                                                               |
    +-------------------------+-------------------------------------+
    | dynamic data length     | multi-guardHookInputData            |
    +-------------------------+-------------------------------------+
    | uint256 32 bytes        | dynamic data without length header  |
    +-------------------------+-------------------------------------+
    */

    function test_SignDataTypeB() public {
        (, uint256 ownerKey) = makeAddrAndKey("owner");
        bytes32 hash = keccak256(abi.encodePacked("hello world"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, hash);
        bytes memory sig = abi.encodePacked(r, s, v);
        assertEq(sig.length, 65);
        uint8 signType = 0;
        bytes memory validatorSignature = abi.encodePacked(signType, sig);
        uint8 dataType = 1;
        bytes memory guardHookInputData = abi.encodePacked("guardHookInputData Test");
        uint256 dynamicDataLength = guardHookInputData.length;

        bytes memory opSig = abi.encodePacked(dataType, dynamicDataLength, guardHookInputData, validatorSignature);

        (bool succ,) = address(this).call(
            abi.encodeWithSelector(this.signTypeDecode.selector, opSig, validatorSignature, guardHookInputData)
        );
        require(succ, "failed");
    }
}
