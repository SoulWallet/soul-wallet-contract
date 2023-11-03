// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

// Refer: https://github.com/adria0/SolRsaVerify/blob/master/src/RsaVerify.sol

/*

    Copyright 2016, Adrià Massanet

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
    
    Checked results with FIPS test vectors
    https://csrc.nist.gov/CSRC/media/Projects/Cryptographic-Algorithm-Validation-Program/documents/dss/186-2rsatestvectors.zip
    file SigVer15_186-3.rsp
    
 */

library RsaVerify {
    uint256 constant sha256ExplicitNullParamByteLen = 17;
    bytes32 constant sha256ExplicitNullParam = 0x3031300d06096086480165030402010500000000000000000000000000000000;
    bytes32 constant sha256ExplicitNullParamMask = 0xffffffffffffffffffffffffffffffffff000000000000000000000000000000;

    uint256 constant sha256ImplicitNullParamByteLen = 15;
    bytes32 constant sha256ImplicitNullParam = 0x302f300b06096086480165030402010000000000000000000000000000000000;
    bytes32 constant sha256ImplicitNullParamMask = 0xffffffffffffffffffffffffffffff0000000000000000000000000000000000;

    /**
     * @dev Verifies a PKCSv1.5 SHA256 signature
     * @param _sha256 is the sha256 of the data
     * @param _s is the signature
     * @param _e is the exponent
     * @param _m is the modulus
     * @return true if success, false otherwise
     */
    function pkcs1Sha256(bytes32 _sha256, bytes memory _s, bytes memory _e, bytes memory _m)
        public
        view
        returns (bool)
    {
        // decipher

        bytes memory input = bytes.concat(bytes32(_s.length), bytes32(_e.length), bytes32(_m.length), _s, _e, _m);
        uint256 inputlen = input.length;

        uint256 decipherlen = _m.length;
        bytes memory decipher = new bytes(decipherlen);
        assembly {
            pop(staticcall(not(0), 0x5, add(input, 0x20), inputlen, add(decipher, 0x20), decipherlen))
        }

        // Check that is well encoded:
        //
        // 0x00 || 0x01 || PS || 0x00 || DigestInfo
        // PS is padding filled with 0xff
        // DigestInfo ::= SEQUENCE {
        //    digestAlgorithm AlgorithmIdentifier,
        //      [optional algorithm parameters]
        //    digest OCTET STRING
        // }

        bool hasNullParam;
        uint256 digestAlgoWithParamLen;

        if (uint8(decipher[decipherlen - 50]) == 0x31) {
            hasNullParam = true;
            digestAlgoWithParamLen = sha256ExplicitNullParamByteLen;
        } else if (uint8(decipher[decipherlen - 48]) == 0x2f) {
            hasNullParam = false;
            digestAlgoWithParamLen = sha256ImplicitNullParamByteLen;
        } else {
            return false;
        }

        uint256 paddingLen = decipherlen - 5 - digestAlgoWithParamLen - 32;

        if (decipher[0] != 0 || decipher[1] != 0x01) {
            return false;
        }
        for (uint256 i = 2; i < 2 + paddingLen;) {
            if (decipher[i] != 0xff) {
                return false;
            }
            unchecked {
                i++;
            }
        }
        if (decipher[2 + paddingLen] != 0) {
            return false;
        }

        // check digest algorithm
        if (digestAlgoWithParamLen == sha256ExplicitNullParamByteLen) {
            assembly {
                //
                // Equivalent code:
                //
                //    for (uint i = 0; i < digestAlgoWithParamLen; i++) {
                //        if (decipher[3 + paddingLen + i] != bytes1(sha256ExplicitNullParam[i])) {
                //            return false;
                //        }
                //    }
                //

                // load decipher[3 + paddingLen + 0]
                let _data := mload(add(add(add(decipher, 0x20), 3), paddingLen))
                // ensure that only the first `sha256ImplicitNullParamByteLen` bytes have data
                _data := and(_data, sha256ExplicitNullParamMask)
                // check that the data is equal to `sha256ExplicitNullParam`
                _data := xor(_data, sha256ExplicitNullParam)
                if gt(_data, 0) {
                    mstore(0x00, false)
                    return(0x00, 0x20)
                }
            }
        } else {
            assembly {
                //
                // Equivalent code:
                //
                //    for (uint i = 0; i < digestAlgoWithParamLen; i++) {
                //        if (decipher[3 + paddingLen + i] != bytes1(sha256ImplicitNullParam[i])) {
                //            return false;
                //        }
                //    }
                //

                // load decipher[3 + paddingLen + 0]
                let _data := mload(add(add(add(decipher, 0x20), 3), paddingLen))
                // ensure that only the first `sha256ImplicitNullParamByteLen` bytes have data
                _data := and(_data, sha256ImplicitNullParamMask)
                // check that the data is equal to `sha256ImplicitNullParam`
                _data := xor(_data, sha256ImplicitNullParam)
                if gt(_data, 0) {
                    mstore(0x00, false)
                    return(0x00, 0x20)
                }
            }
        }

        // check digest

        if (
            decipher[3 + paddingLen + digestAlgoWithParamLen] != 0x04
                || decipher[4 + paddingLen + digestAlgoWithParamLen] != 0x20
        ) {
            return false;
        }

        assembly {
            //
            // Equivalent code:
            //
            //    for (uint i = 0;i<_sha256.length;i++) {
            //        if (decipher[5+paddingLen+digestAlgoWithParamLen+i]!=_sha256[i]) {
            //            return false;
            //        }
            //    }
            //

            // load decipher[5 + paddingLen + digestAlgoWithParamLen + 0]
            let _data := mload(add(add(add(add(decipher, 0x20), 5), paddingLen), digestAlgoWithParamLen))
            // check that the data is equal to `_sha256`
            _data := xor(_data, _sha256)
            if gt(_data, 0) {
                mstore(0x00, false)
                return(0x00, 0x20)
            }
        }

        return true;
    }
}
