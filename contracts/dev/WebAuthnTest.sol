// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.20;

import "../libraries/WebAuthn.sol";

contract WebAuthnTest {
    function testSignature() external view {
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
        bytes32 challenge = 0x83714056da6e6910b51595330c2c2cdfbf718f2deff5bdd84b95df7a7f36f6dd;
        bytes memory authenticatorData = hex"49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97630500000000";
        string memory clientDataSuffix = "\",\"origin\":\"http://localhost:5500\",\"crossOrigin\":false}";
        bool succ = WebAuthn.verifySignature(Qx, Qy, r, s, challenge, authenticatorData, clientDataSuffix);
        require(succ, "WebAuthn verifySignature failed");
    }
}
