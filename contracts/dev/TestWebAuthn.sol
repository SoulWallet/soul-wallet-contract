// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.20;

import "../libraries/WebAuthn.sol";
import "../libraries/RS256Verify.sol";

contract TestWebAuthn {
    function signatureP256Test() external view {
        /* 
        register:
                {
                    "username": "MyUsername",
                    "credential": {
                        "id": "Z5v4MnDJUhMpVBgphmNb7FQ9ylbDXnPXcde_i9QdEsM",
                        "publicKey": "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE6J6LS-lD-ttNxZn-Lor4enm0OK3eMoo7ctQzJFBs1bZPv-Si-ZNHg8Oxr3Eu6Hq8CPV255NG78O4NV2TG9e5dg==",
                        "algorithm": "ES256"
                    },
                    "authenticatorData": "SZYN5YgOjGh0NBcPZHZgW4_krrmihjLHmVzzuoMdl2NFAAAAAK3OAAI1vMYKZIsLJfHwVQMAIGeb-DJwyVITKVQYKYZjW-xUPcpWw15z13HXv4vUHRLDpQECAyYgASFYIOiei0vpQ_rbTcWZ_i6K-Hp5tDit3jKKO3LUMyRQbNW2IlggT7_kovmTR4PDsa9xLuh6vAj1dueTRu_DuDVdkxvXuXY=",
                    "clientData": "eyJ0eXBlIjoid2ViYXV0aG4uY3JlYXRlIiwiY2hhbGxlbmdlIjoiZzNGQVZ0cHVhUkMxRlpVekRDd3MzNzl4ankzdjliM1lTNVhmZW44Mjl0MCIsIm9yaWdpbiI6Imh0dHA6Ly9sb2NhbGhvc3Q6NTUwMCIsImNyb3NzT3JpZ2luIjpmYWxzZX0="
                }

                publicKey -> Qx, Qy
                    Qx: 0xe89e8b4be943fadb4dc599fe2e8af87a79b438adde328a3b72d43324506cd5b6
                    Qy: 0x4fbfe4a2f9934783c3b1af712ee87abc08f576e79346efc3b8355d931bd7b976

            userOpHash: 0x83714056da6e6910b51595330c2c2cdfbf718f2deff5bdd84b95df7a7f36f6dd

            sign:
                {
                    "credentialId": "Z5v4MnDJUhMpVBgphmNb7FQ9ylbDXnPXcde_i9QdEsM",
                    "authenticatorData": "SZYN5YgOjGh0NBcPZHZgW4_krrmihjLHmVzzuoMdl2MFAAAAAA==",
                    "clientData": "eyJ0eXBlIjoid2ViYXV0aG4uZ2V0IiwiY2hhbGxlbmdlIjoiZzNGQVZ0cHVhUkMxRlpVekRDd3MzNzl4ankzdjliM1lTNVhmZW44Mjl0MCIsIm9yaWdpbiI6Imh0dHA6Ly9sb2NhbGhvc3Q6NTUwMCIsImNyb3NzT3JpZ2luIjpmYWxzZX0=",
                    "signature": "MEUCICrj3f5MxBTcD61_86XJYNHO4SEXItMJmt525awYJnMaAiEAh-XWVPNX5M1stSUSstpNkergrkjp2JLOUyuTUvY6VdY="
                }
                authenticatorData: SZYN5YgOjGh0NBcPZHZgW4_krrmihjLHmVzzuoMdl2MFAAAAAA==
                authenticatorData decode to hex: 0x49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97630500000000

                decode clientData: {"type":"webauthn.get","challenge":"g3FAVtpuaRC1FZUzDCws379xjy3v9b3YS5Xfen829t0","origin":"http://localhost:5500","crossOrigin":false}
                decode DER signature to r,s: 
                    r 0x2ae3ddfe4cc414dc0fad7ff3a5c960d1cee1211722d3099ade76e5ac1826731a
                    s 0x87e5d654f357e4cd6cb52512b2da4d91eae0ae48e9d892ce532b9352f63a55d6
       
        */

        uint256 Qx = uint256(0xe89e8b4be943fadb4dc599fe2e8af87a79b438adde328a3b72d43324506cd5b6);
        uint256 Qy = uint256(0x4fbfe4a2f9934783c3b1af712ee87abc08f576e79346efc3b8355d931bd7b976);
        uint256 r = uint256(0x2ae3ddfe4cc414dc0fad7ff3a5c960d1cee1211722d3099ade76e5ac1826731a);
        uint256 s = uint256(0x87e5d654f357e4cd6cb52512b2da4d91eae0ae48e9d892ce532b9352f63a55d6);
        bytes32 userOpHash = 0x83714056da6e6910b51595330c2c2cdfbf718f2deff5bdd84b95df7a7f36f6dd;
        bytes memory authenticatorData = hex"49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97630500000000";
        string memory clientDataSuffix = "\",\"origin\":\"http://localhost:5500\",\"crossOrigin\":false}";
        bool succ = WebAuthn.verifyP256Signature(Qx, Qy, r, s, userOpHash, authenticatorData, clientDataSuffix);
        require(succ, "WebAuthn-P256 verifySignature failed");
    }

    function signatureRS256Test() external view {
        bytes memory e = hex"0000000000000000000000000000000000000000000000000000000000010001";

        bytes memory Msg =
            hex"49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d976305000000013cdb7da78783855f4167a4a0d6fdccaeff7a8596ce7ca47c7a4dbfe6b8d6b43a";

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

        bytes32 message = sha256(Msg);
        bool succ = RS256Verify.RSASSA_PSS_VERIFY(n, e, message, S);
        require(succ, "WebAuthn-RS256 verifySignature failed");
    }

    function signatureRS256Test2() external view {
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
        bytes memory clientDataJSON = bytes.concat(bytes(clientDataPrefix), challengeBase64, bytes(clientDataSuffix));
        bytes32 clientHash = sha256(clientDataJSON);
        bytes memory authenticatorData = hex"49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97630500000001";
        bytes32 message = sha256(bytes.concat(authenticatorData, clientHash));
        bytes memory e = hex"0000000000000000000000000000000000000000000000000000000000010001";
        bytes memory n =
            hex"c6807412ed8d616565508c879292686bb1db6f0561b62c7b66a2d3806d161c0ccef888d2c1efcf061e268a15e61e7d023646014c33b1ead31bef0e5379558e6ff71249b143c03abec33a2b055fc8e0a947393512e7e26ad33f0ad4aabfe32d0642965856d8e20204a44d78e36cc90db2a12cfbc37fa97360efd3a735c625ab814d6f6bb7c63abe261bbd9c52681c6221f936d617dc84de61556074f6c1d73b3ffd242d2940d3c02c5a269e390bd8e6b6301a5a0a339910f6480403d27d32c2ff2b9bf33bae45c36f423025ca41f05c97be5148b2cb276b31441274100bf3ca0b50da1ee04511be9bdbb4f12b7579ab3da780bc2c615e2a49f5e1f750b034d0af";
        bytes memory signature =
            hex"357a51b26e22dcfb87346bb6938cfb2b066d48d4c36cafd30ac105fe345199966f24c87fa66791d4c2341b97fa07421ef4115a9923e6249c53887b6f2313df60654083758fe7104286490e1a37481246395dcb097a86645dc3251afa5c87e4bc8f2960cfe3efa34c44bbee0fe3d602866c81a5fc432709443c623595556670a427502c63c1e6a86761c8b326b5f503bdcfdcf1f00871f330a9fddf6ae11adcff4a5f411edec30019c86936f8064b70f88cdb56ba6635175f7ef5c74f52de9db5498e4c4d4b75c8a3210e5b1a631af271c4b613a8752b2a1cea499bd81115d9ed34305d9ab4af753dc9b9630478fdb0787e5f5e0efb76504d15eff5fd02a38bf1";
        bool success = RS256Verify.RSASSA_PSS_VERIFY(n, e, message, signature);
        require(success, "WebAuthn-RS256 verifySignature failed");
    }

    function recoverTest(bytes32 userOpHash, bytes calldata packedSignature) public view returns (bytes32) {
        bytes32 publicKey = WebAuthn.recover(userOpHash, packedSignature);
        if (publicKey == 0) {
            revert("WebAuthn-p256 recover failed");
        }
        return publicKey;
    }
}
