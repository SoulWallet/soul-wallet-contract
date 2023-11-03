// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.20;

import "../libraries/WebAuthn.sol";
import "../libraries/RsaVerify.sol";

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
        bool succ = RsaVerify.pkcs1Sha256(message, S, e, n);
        require(succ, "WebAuthn-RS256 verifySignature failed");
    }

    function recoverTest(bytes32 userOpHash, bytes calldata signature) public view returns (bytes32) {
        bytes32 publicKey = WebAuthn.recover(userOpHash, signature);
        if (publicKey == 0) {
            revert("WebAuthn recover failed");
        }
        return publicKey;
    }
}
