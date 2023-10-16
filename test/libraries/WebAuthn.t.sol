// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@source/dev/TestWebAuthn.sol";

contract WebAuthnTest is Test {
    TestWebAuthn testWebAuthn;

    function setUp() public {
        testWebAuthn = new TestWebAuthn();
    }

    function test_Signature() public view {
        testWebAuthn.signatureTest();
    }

    function test_Recover1() public {
        bytes32 expected;
        {
            uint256 Qx = uint256(0xe89e8b4be943fadb4dc599fe2e8af87a79b438adde328a3b72d43324506cd5b6);
            uint256 Qy = uint256(0x4fbfe4a2f9934783c3b1af712ee87abc08f576e79346efc3b8355d931bd7b976);
            expected = keccak256(abi.encodePacked(Qx, Qy));
        }
        bytes32 userOpHash = 0x83714056da6e6910b51595330c2c2cdfbf718f2deff5bdd84b95df7a7f36f6dd;
        bytes memory sig;
        assembly {
            let ptr := mload(0x40)
            mstore(0x40, add(ptr, mul(8, 0x20)))
            mstore(ptr, 0xc5) // signature length
            mstore(add(ptr, 0x20), 0x2ae3ddfe4cc414dc0fad7ff3a5c960d1cee1211722d3099ade76e5ac1826731a) // r
            mstore(add(ptr, 0x40), 0x87e5d654f357e4cd6cb52512b2da4d91eae0ae48e9d892ce532b9352f63a55d6) // s
            mstore(add(ptr, 0x60), 0x1c0025002449960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3) // 0x1c00250024: v=0x1c, authenticatorDataLength=0x25, clientDataPrefixLength=0x24
            mstore(add(ptr, 0x80), 0xba831d976305000000007b2274797065223a22776562617574686e2e67657422)
            mstore(add(ptr, 0xa0), 0x2c226368616c6c656e6765223a22222c226f726967696e223a22687474703a2f)
            mstore(add(ptr, 0xc0), 0x2f6c6f63616c686f73743a35353030222c2263726f73734f726967696e223a66)
            mstore(add(ptr, 0xe0), 0x616c73657d000000000000000000000000000000000000000000000000000000)
            sig := ptr
        }
        bytes32 publicKey = testWebAuthn.recoverTest(userOpHash, sig);
        assertEq(publicKey, expected);
    }

    function test_Recover2() public {
        bytes32 expected;
        {
            uint256 Qx = uint256(0xe89e8b4be943fadb4dc599fe2e8af87a79b438adde328a3b72d43324506cd5b6);
            uint256 Qy = uint256(0x4fbfe4a2f9934783c3b1af712ee87abc08f576e79346efc3b8355d931bd7b976);
            expected = keccak256(abi.encodePacked(Qx, Qy));
        }
        bytes32 userOpHash = 0x83714056da6e6910b51595330c2c2cdfbf718f2deff5bdd84b95df7a7f36f6dd;

        bytes memory sig;
        assembly {
            let ptr := mload(0x40)
            mstore(0x40, add(ptr, mul(7, 0x20)))
            mstore(ptr, 0xa1) // signature length
            mstore(add(ptr, 0x20), 0x2ae3ddfe4cc414dc0fad7ff3a5c960d1cee1211722d3099ade76e5ac1826731a) // r
            mstore(add(ptr, 0x40), 0x87e5d654f357e4cd6cb52512b2da4d91eae0ae48e9d892ce532b9352f63a55d6) // s
            mstore(add(ptr, 0x60), 0x1c0025000049960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3) // 0x1c00250000: v=0x1c, authenticatorDataLength=0x25, clientDataPrefixLength=0x00
            mstore(add(ptr, 0x80), 0xba831d97630500000000222c226f726967696e223a22687474703a2f2f6c6f63)
            mstore(add(ptr, 0xa0), 0x616c686f73743a35353030222c2263726f73734f726967696e223a66616c7365)
            mstore(add(ptr, 0xc0), 0x7d00000000000000000000000000000000000000000000000000000000000000)
            sig := ptr
        }
        bytes32 publicKey = testWebAuthn.recoverTest(userOpHash, sig);
        assertEq(publicKey, expected);
    }
}
