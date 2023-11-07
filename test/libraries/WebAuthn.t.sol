// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@source/dev/TestWebAuthn.sol";

contract WebAuthnTest is Test {
    TestWebAuthn testWebAuthn;

    function setUp() public {
        testWebAuthn = new TestWebAuthn();
    }

    function test_P256Signature() public view {
        testWebAuthn.signatureP256Test();
    }

    function test_RS256Signature() public view {
        testWebAuthn.signatureRS256Test();
    }

    function test_RecoverP256_1() public {
        bytes32 expected;
        {
            uint256 Qx = uint256(0xe89e8b4be943fadb4dc599fe2e8af87a79b438adde328a3b72d43324506cd5b6);
            uint256 Qy = uint256(0x4fbfe4a2f9934783c3b1af712ee87abc08f576e79346efc3b8355d931bd7b976);
            expected = keccak256(abi.encodePacked(Qx, Qy));
        }
        bytes32 userOpHash = 0x83714056da6e6910b51595330c2c2cdfbf718f2deff5bdd84b95df7a7f36f6dd;
        bytes memory sig = hex"00" // algorithmType
            hex"2ae3ddfe4cc414dc0fad7ff3a5c960d1cee1211722d3099ade76e5ac1826731a" // r
            hex"87e5d654f357e4cd6cb52512b2da4d91eae0ae48e9d892ce532b9352f63a55d6" // s
            hex"1c0025002449960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3" // 0x1c00250024: v=0x1c, authenticatorDataLength=0x25, clientDataPrefixLength=0x24
            hex"ba831d976305000000007b2274797065223a22776562617574686e2e67657422"
            hex"2c226368616c6c656e6765223a22222c226f726967696e223a22687474703a2f"
            hex"2f6c6f63616c686f73743a35353030222c2263726f73734f726967696e223a66" hex"616c73657d";

        bytes32 publicKey = testWebAuthn.recoverTest(userOpHash, sig);
        assertEq(publicKey, expected);
    }

    function test_RecoverP256_2() public {
        bytes32 expected;
        {
            uint256 Qx = uint256(0xe89e8b4be943fadb4dc599fe2e8af87a79b438adde328a3b72d43324506cd5b6);
            uint256 Qy = uint256(0x4fbfe4a2f9934783c3b1af712ee87abc08f576e79346efc3b8355d931bd7b976);
            expected = keccak256(abi.encodePacked(Qx, Qy));
        }
        bytes32 userOpHash = 0x83714056da6e6910b51595330c2c2cdfbf718f2deff5bdd84b95df7a7f36f6dd;

        bytes memory sig = hex"00" // algorithmType
            hex"2ae3ddfe4cc414dc0fad7ff3a5c960d1cee1211722d3099ade76e5ac1826731a" // r
            hex"87e5d654f357e4cd6cb52512b2da4d91eae0ae48e9d892ce532b9352f63a55d6" // s
            hex"1c" // v=0x1c
            hex"0025" // authenticatorDataLength=0x25
            hex"0000" // clientDataPrefixLength=0x00
            hex"49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d9763"
            hex"0500000000222c226f726967696e223a22687474703a2f2f6c6f63616c686f73"
            hex"743a35353030222c2263726f73734f726967696e223a66616c73657d";

        bytes32 publicKey = testWebAuthn.recoverTest(userOpHash, sig);
        assertEq(publicKey, expected);
    }

    function test_RecoverRS256() public {
        /*
            register:
                {
                    "credential": {
                        "publicKey": "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAxoB0Eu2NYWVlUIyHkpJoa7HbbwVhtix7ZqLTgG0WHAzO-IjSwe_PBh4mihXmHn0CNkYBTDOx6tMb7w5TeVWOb_cSSbFDwDq-wzorBV_I4KlHOTUS5-Jq0z8K1Kq_4y0GQpZYVtjiAgSkTXjjbMkNsqEs-8N_qXNg79OnNcYlq4FNb2u3xjq-Jhu9nFJoHGIh-TbWF9yE3mFVYHT2wdc7P_0kLSlA08AsWiaeOQvY5rYwGloKM5kQ9kgEA9J9MsL_K5vzO65Fw29CMCXKQfBcl75RSLLLJ2sxRBJ0EAvzygtQ2h7gRRG-m9u08St1eas9p4C8LGFeKkn14fdQsDTQrwIDAQAB",
                        "algorithm": "RS256"
                    }
                }

                publicKey -> e,n
                e: 0x010001
                n: 0xc6807412ed8d616565508c879292686bb1db6f0561b62c7b66a2d3806d161c0ccef888d2c1efcf061e268a15e61e7d023646014c33b1ead31bef0e5379558e6ff71249b143c03abec33a2b055fc8e0a947393512e7e26ad33f0ad4aabfe32d0642965856d8e20204a44d78e36cc90db2a12cfbc37fa97360efd3a735c625ab814d6f6bb7c63abe261bbd9c52681c6221f936d617dc84de61556074f6c1d73b3ffd242d2940d3c02c5a269e390bd8e6b6301a5a0a339910f6480403d27d32c2ff2b9bf33bae45c36f423025ca41f05c97be5148b2cb276b31441274100bf3ca0b50da1ee04511be9bdbb4f12b7579ab3da780bc2c615e2a49f5e1f750b034d0af
                    

            userOpHash: 0x83714056da6e6910b51595330c2c2cdfbf718f2deff5bdd84b95df7a7f36f6dd

            sign:
                // {"type":"webauthn.get","challenge":"g3FAVtpuaRC1FZUzDCws379xjy3v9b3YS5Xfen829t0","origin":"http://localhost:5500","crossOrigin":false}
                {
                    "credentialId": "7tHBySevVSHJIYJJWSNS_f3UDx9WgBQ1UbLq60E2ehs",
                    "authenticatorData": "SZYN5YgOjGh0NBcPZHZgW4_krrmihjLHmVzzuoMdl2MFAAAAAQ==",
                    "clientData": "eyJ0eXBlIjoid2ViYXV0aG4uZ2V0IiwiY2hhbGxlbmdlIjoiZzNGQVZ0cHVhUkMxRlpVekRDd3MzNzl4ankzdjliM1lTNVhmZW44Mjl0MCIsIm9yaWdpbiI6Imh0dHA6Ly9sb2NhbGhvc3Q6NTUwMCIsImNyb3NzT3JpZ2luIjpmYWxzZX0=",
                    "signature": "NXpRsm4i3PuHNGu2k4z7KwZtSNTDbK_TCsEF_jRRmZZvJMh_pmeR1MI0G5f6B0Ie9BFamSPmJJxTiHtvIxPfYGVAg3WP5xBChkkOGjdIEkY5XcsJeoZkXcMlGvpch-S8jylgz-Pvo0xEu-4P49YChmyBpfxDJwlEPGI1lVVmcKQnUCxjweaoZ2HIsya19QO9z9zx8Ahx8zCp_d9q4Rrc_0pfQR7ewwAZyGk2-AZLcPiM21a6ZjUXX371x09S3p21SY5MTUt1yKMhDlsaYxryccS2E6h1Kyoc6kmb2BEV2e00MF2atK91Pcm5YwR4_bB4fl9eDvt2UE0V7_X9AqOL8Q=="
                }
                authenticatorData: SZYN5YgOjGh0NBcPZHZgW4_krrmihjLHmVzzuoMdl2MFAAAAAQ==
                authenticatorData decode to hex: 0x49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97630500000001

                decode clientData: {"type":"webauthn.get","challenge":"g3FAVtpuaRC1FZUzDCws379xjy3v9b3YS5Xfen829t0","origin":"http://localhost:5500","crossOrigin":false}
                signature to hex:
                0x357a51b26e22dcfb87346bb6938cfb2b066d48d4c36cafd30ac105fe345199966f24c87fa66791d4c2341b97fa07421ef4115a9923e6249c53887b6f2313df60654083758fe7104286490e1a37481246395dcb097a86645dc3251afa5c87e4bc8f2960cfe3efa34c44bbee0fe3d602866c81a5fc432709443c623595556670a427502c63c1e6a86761c8b326b5f503bdcfdcf1f00871f330a9fddf6ae11adcff4a5f411edec30019c86936f8064b70f88cdb56ba6635175f7ef5c74f52de9db5498e4c4d4b75c8a3210e5b1a631af271c4b613a8752b2a1cea499bd81115d9ed34305d9ab4af753dc9b9630478fdb0787e5f5e0efb76504d15eff5fd02a38bf1

       
        */
        bytes32 userOpHash = 0x83714056da6e6910b51595330c2c2cdfbf718f2deff5bdd84b95df7a7f36f6dd;
        bytes memory challengeBase64 = bytes(Base64Url.encode(bytes.concat(userOpHash)));
        string memory clientDataPrefix = "{\"type\":\"webauthn.get\",\"challenge\":\"";
        string memory clientDataSuffix = "\",\"origin\":\"http://localhost:5500\",\"crossOrigin\":false}";
        //bytes memory clientDataJSON = bytes.concat(bytes(clientDataPrefix), challengeBase64, bytes(clientDataSuffix));
        //bytes32 clientHash = sha256(clientDataJSON);
        bytes memory authenticatorData = hex"49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97630500000001";
        //bytes32 message = sha256(bytes.concat(authenticatorData, clientHash));

        bytes memory n =
            hex"c6807412ed8d616565508c879292686bb1db6f0561b62c7b66a2d3806d161c0ccef888d2c1efcf061e268a15e61e7d023646014c33b1ead31bef0e5379558e6ff71249b143c03abec33a2b055fc8e0a947393512e7e26ad33f0ad4aabfe32d0642965856d8e20204a44d78e36cc90db2a12cfbc37fa97360efd3a735c625ab814d6f6bb7c63abe261bbd9c52681c6221f936d617dc84de61556074f6c1d73b3ffd242d2940d3c02c5a269e390bd8e6b6301a5a0a339910f6480403d27d32c2ff2b9bf33bae45c36f423025ca41f05c97be5148b2cb276b31441274100bf3ca0b50da1ee04511be9bdbb4f12b7579ab3da780bc2c615e2a49f5e1f750b034d0af";
        bytes memory signature =
            hex"357a51b26e22dcfb87346bb6938cfb2b066d48d4c36cafd30ac105fe345199966f24c87fa66791d4c2341b97fa07421ef4115a9923e6249c53887b6f2313df60654083758fe7104286490e1a37481246395dcb097a86645dc3251afa5c87e4bc8f2960cfe3efa34c44bbee0fe3d602866c81a5fc432709443c623595556670a427502c63c1e6a86761c8b326b5f503bdcfdcf1f00871f330a9fddf6ae11adcff4a5f411edec30019c86936f8064b70f88cdb56ba6635175f7ef5c74f52de9db5498e4c4d4b75c8a3210e5b1a631af271c4b613a8752b2a1cea499bd81115d9ed34305d9ab4af753dc9b9630478fdb0787e5f5e0efb76504d15eff5fd02a38bf1";

        bytes32 expected;
        {
            bytes memory e = hex"0000000000000000000000000000000000000000000000000000000000010001";
            expected = keccak256(abi.encodePacked(e, n));
        }

        /*
            signature layout:
            1. n(exponent) length (2 byte max to 8192 bits key)
            2. authenticatorData length (2 byte max 65535)
            3. clientDataPrefix length (2 byte max 65535)
            4. n(exponent) (exponent,dynamic bytes)
            5. signature (signature,signature.length== n.length)
            6. authenticatorData
            7. clientDataPrefix
            8. clientDataSuffix

        */

        bytes memory sig = hex"01" // algorithmType
            hex"0100" //  1. n(exponent) length (2 byte max to 8192 bits key)
            hex"0025" // 2. authenticatorData length (2 byte max 65535)
            hex"0000" // 3. clientDataPrefix length (2 byte max 65535)
            /* 4. n(exponent) (exponent,dynamic bytes) begin */
            hex"c6807412ed8d616565508c879292686bb1db6f0561b62c7b66a2d3806d161c0ccef888d2c1efcf061e268a15e61e7d023646014c33b1ead31bef0e5379558e6ff71249b143c03abec33a2b055fc8e0a947393512e7e26ad33f0ad4aabfe32d0642965856d8e20204a44d78e36cc90db2a12cfbc37fa97360efd3a735c625ab814d6f6bb7c63abe261bbd9c52681c6221f936d617dc84de61556074f6c1d73b3ffd242d2940d3c02c5a269e390bd8e6b6301a5a0a339910f6480403d27d32c2ff2b9bf33bae45c36f423025ca41f05c97be5148b2cb276b31441274100bf3ca0b50da1ee04511be9bdbb4f12b7579ab3da780bc2c615e2a49f5e1f750b034d0af"
            /* 4. n(exponent) (exponent,dynamic bytes) end */
            /* 5. signature (signature,signature.length== n.length) begin */
            hex"357a51b26e22dcfb87346bb6938cfb2b066d48d4c36cafd30ac105fe345199966f24c87fa66791d4c2341b97fa07421ef4115a9923e6249c53887b6f2313df60654083758fe7104286490e1a37481246395dcb097a86645dc3251afa5c87e4bc8f2960cfe3efa34c44bbee0fe3d602866c81a5fc432709443c623595556670a427502c63c1e6a86761c8b326b5f503bdcfdcf1f00871f330a9fddf6ae11adcff4a5f411edec30019c86936f8064b70f88cdb56ba6635175f7ef5c74f52de9db5498e4c4d4b75c8a3210e5b1a631af271c4b613a8752b2a1cea499bd81115d9ed34305d9ab4af753dc9b9630478fdb0787e5f5e0efb76504d15eff5fd02a38bf1"
            /* 5. signature (signature,signature.length== n.length) end */
            // 6. authenticatorData
            hex"49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97630500000001"
            // 7. clientDataPrefix
            // 8. clientDataSuffix:  string memory clientDataSuffix = "\",\"origin\":\"http://localhost:5500\",\"crossOrigin\":false}";
            hex"222c226f726967696e223a22687474703a2f2f6c6f63616c686f73743a35353030222c2263726f73734f726967696e223a66616c73657d";

        bytes32 publicKey = testWebAuthn.recoverTest(userOpHash, sig);
        assertEq(publicKey, expected);
    }
}
