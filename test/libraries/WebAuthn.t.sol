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

    function test_RecoverRS256_1() public {
        // {
        //     const authentication = JSON.parse('{"credentialId":"P6OJhYxMzvv0poqoqGSBDQh5i7auBgsKsv9yOVy8VBw","authenticatorData":"SZYN5YgOjGh0NBcPZHZgW4_krrmihjLHmVzzuoMdl2MFAAAAAQ==","clientData":"eyJ0eXBlIjoid2ViYXV0aG4uZ2V0IiwiY2hhbGxlbmdlIjoiZzNGQVZ0cHVhUkMxRlpVekRDd3MzNzl4ankzdjliM1lTNVhmZW44Mjl0MCIsIm9yaWdpbiI6Imh0dHA6Ly9sb2NhbGhvc3Q6NTUwMCIsImNyb3NzT3JpZ2luIjpmYWxzZX0=","signature":"rdgIX23DZX4csDS5ReT6V99At-rAOCKBobIlpB3Eu6iSMPDDwU-MKpeWNnEKZG_n1ACp3fxUXwrCRd7p9ni_Y4VCn1wXGbeigi4kLq9u3FLeF6vQcfaerT2OdsLzNCT4JH39Hc6p-75XI-OTG0g4g0Ov53cOgrCnxmWSyQ4yoVpt2lhQzm76TchvUTzmiqdk66mHXGpDoMc9g76_-r0Zu3kYEXeQcPmhxgcr5QRsgdvCpXa-upZGICWMKh1nlZVuF6dhm-smy7UAr2VVT6hL7vhgim4tOEn4iTxQ17RQyr_VO-M5Bh3YaR5zRFw8kpBCXpgTKv6HbP3dJA5f6Q9z-A=="}');
        //     const credentialKey = JSON.parse('{"id":"P6OJhYxMzvv0poqoqGSBDQh5i7auBgsKsv9yOVy8VBw","publicKey":"MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAur1HqkddKPsLyEC-aSw-j763u7geMD07omLDqoP9WDKR9gobF8Fo7XWsKPbghOaaUpaoB8ZnrNurZ5RCTkdObxPWVEwTm7ORMzABRavPLLVC5b3Jm_oOHOY3YxZn21u9xl8R0KirtdLLwK5hinupdf5BIflbd2LAjpEubZQVv0_x73Xw3quYM-N_CuInOkIVIO1kuwYkZGNpiro-4ucFZwiZ2miZsNEVHyYfocW1yiaagF_BLLbxDoezqAU21j5e5SEI_Rv8dFqw3jJiBdfhb2-9rGxl0LkfRqdPZ3L67_qCvm-Qada9F5DnJh-FyjKxk03ByCNFr3KcQCNAHR4pSQIDAQAB","algorithm":"RS256"}');
        //     const expected = JSON.parse('{"challenge":"g3FAVtpuaRC1FZUzDCws379xjy3v9b3YS5Xfen829t0","origin":"http://localhost:5500"}');
        //     const authenticationParsed = await server.verifyAuthentication(authentication, credentialKey, expected);
        //     console.log(JSON.stringify(authenticationParsed, null, 2));
        // }
        bytes memory authenticatorData = hex"49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97630500000001";

        bytes memory e = hex"010001";

        bytes memory S = hex"add8085f6dc3657e1cb034b945e4fa57df40b7eac0382281a1b225a41dc4bba8"
            hex"9230f0c3c14f8c2a979636710a646fe7d400a9ddfc545f0ac245dee9f678bf63"
            hex"85429f5c1719b7a2822e242eaf6edc52de17abd071f69ead3d8e76c2f33424f8"
            hex"247dfd1dcea9fbbe5723e3931b48388343afe7770e82b0a7c66592c90e32a15a"
            hex"6dda5850ce6efa4dc86f513ce68aa764eba9875c6a43a0c73d83bebffabd19bb"
            hex"791811779070f9a1c6072be5046c81dbc2a576beba964620258c2a1d6795956e"
            hex"17a7619beb26cbb500af65554fa84beef8608a6e2d3849f8893c50d7b450cabf"
            hex"d53be339061dd8691e73445c3c9290425e98132afe876cfddd240e5fe90f73f8";

        bytes memory n = hex"babd47aa475d28fb0bc840be692c3e8fbeb7bbb81e303d3ba262c3aa83fd5832"
            hex"91f60a1b17c168ed75ac28f6e084e69a5296a807c667acdbab6794424e474e6f"
            hex"13d6544c139bb39133300145abcf2cb542e5bdc99bfa0e1ce637631667db5bbd"
            hex"c65f11d0a8abb5d2cbc0ae618a7ba975fe4121f95b7762c08e912e6d9415bf4f"
            hex"f1ef75f0deab9833e37f0ae2273a421520ed64bb06246463698aba3ee2e70567"
            hex"0899da6899b0d1151f261fa1c5b5ca269a805fc12cb6f10e87b3a80536d63e5e"
            hex"e52108fd1bfc745ab0de326205d7e16f6fbdac6c65d0b91f46a74f6772faeffa"
            hex"82be6f9069d6bd1790e7261f85ca32b1934dc1c82345af729c4023401d1e2949";
        bytes32 expected;
        {
            uint256 Qx = uint256(0xe89e8b4be943fadb4dc599fe2e8af87a79b438adde328a3b72d43324506cd5b6);
            uint256 Qy = uint256(0x4fbfe4a2f9934783c3b1af712ee87abc08f576e79346efc3b8355d931bd7b976);
            expected = keccak256(abi.encodePacked(Qx, Qy));
        }
        bytes32 userOpHash = 0x83714056da6e6910b51595330c2c2cdfbf718f2deff5bdd84b95df7a7f36f6dd;

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
            hex"babd47aa475d28fb0bc840be692c3e8fbeb7bbb81e303d3ba262c3aa83fd5832"
            hex"91f60a1b17c168ed75ac28f6e084e69a5296a807c667acdbab6794424e474e6f"
            hex"13d6544c139bb39133300145abcf2cb542e5bdc99bfa0e1ce637631667db5bbd"
            hex"c65f11d0a8abb5d2cbc0ae618a7ba975fe4121f95b7762c08e912e6d9415bf4f"
            hex"f1ef75f0deab9833e37f0ae2273a421520ed64bb06246463698aba3ee2e70567"
            hex"0899da6899b0d1151f261fa1c5b5ca269a805fc12cb6f10e87b3a80536d63e5e"
            hex"e52108fd1bfc745ab0de326205d7e16f6fbdac6c65d0b91f46a74f6772faeffa"
            hex"82be6f9069d6bd1790e7261f85ca32b1934dc1c82345af729c4023401d1e2949"
            /* 4. n(exponent) (exponent,dynamic bytes) end */

            /* 5. signature (signature,signature.length== n.length) begin */
            hex"add8085f6dc3657e1cb034b945e4fa57df40b7eac0382281a1b225a41dc4bba8"
            hex"9230f0c3c14f8c2a979636710a646fe7d400a9ddfc545f0ac245dee9f678bf63"
            hex"85429f5c1719b7a2822e242eaf6edc52de17abd071f69ead3d8e76c2f33424f8"
            hex"247dfd1dcea9fbbe5723e3931b48388343afe7770e82b0a7c66592c90e32a15a"
            hex"6dda5850ce6efa4dc86f513ce68aa764eba9875c6a43a0c73d83bebffabd19bb"
            hex"791811779070f9a1c6072be5046c81dbc2a576beba964620258c2a1d6795956e"
            hex"17a7619beb26cbb500af65554fa84beef8608a6e2d3849f8893c50d7b450cabf"
            hex"d53be339061dd8691e73445c3c9290425e98132afe876cfddd240e5fe90f73f8"
            /* 5. signature (signature,signature.length== n.length) end */

            // 6. authenticatorData
            hex"49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97630500000001"
            // 7. clientDataPrefix
            // 8. clientDataSuffix: ","origin":"http://localhost:5500"}
            hex"222c226f726967696e223a22687474703a2f2f6c6f63616c686f73743a35353030227d";

        bytes32 publicKey = testWebAuthn.recoverTest(userOpHash, sig);
        assertEq(publicKey, expected);
    }
}
