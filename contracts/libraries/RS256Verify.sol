// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * @title RS256Verify
 * @author https://github.com/jayden-sudo
 *
 * The code strictly follows the RSASSA-PKCS1-v1_5 signature verification operation steps outlined in RFC 8017.
 * It takes a signature, message, and public key as inputs and verifies if the signature is valid for the
 * given message using the provided public key.
 * reference: https://datatracker.ietf.org/doc/html/rfc8017#section-8.1.2
 *
 * This code has passed the complete tests of the `Algorithm Validation Testing Requirements`:https://csrc.nist.gov/Projects/Cryptographic-Algorithm-Validation-Program/Digital-Signatures#rsa2vs
 * `FIPS 186-4` https://csrc.nist.gov/CSRC/media/Projects/Cryptographic-Algorithm-Validation-Program/documents/dss/186-3rsatestvectors.zip
 *
 * LICENSE: MIT
 * Copyright (c) 2023 Jayden
 */
library RS256Verify {
    /**
     *
     * @param n signer's RSA public key - n
     * @param e signer's RSA public key - e
     * @param H H = sha256(M) - message digest
     * @param S signature to be verified, an octet string of length k, where k is the length in octets of the RSA modulus n
     */
    function RSASSA_PSS_VERIFY(bytes memory n, bytes memory e, bytes32 H, bytes memory S)
        internal
        view
        returns (bool)
    {
        uint256 k = n.length;
        // 1. Length checking: If the length of S is not k octets, output "invalid signature" and stop.
        if (k != S.length) {
            return false;
        }

        // 2. RSA verification:
        /* 
                a.  Convert the signature S to an integer signature representative s (see Section 4.2):
                    s = OS2IP (S).
        */
        /*
            c.  Convert the message representative m to an encoded message
                  EM of length k octets (see Section 4.1):
                     EM = I2OSP (m, k).
        */

        // bytes memory EM = m;

        /*  
            1.  Encode the algorithm ID for the hash function and the hash
                value into an ASN.1 value of type DigestInfo (see
                Appendix A.2.4) with the DER, where the type DigestInfo has
                the syntax
     
                    DigestInfo ::= SEQUENCE {
                        digestAlgorithm AlgorithmIdentifier,
                        digest OCTET STRING
                    }
     
                The first field identifies the hash function and the second
                contains the hash value.  Let T be the DER encoding of the
                DigestInfo value (see the notes below), and let tLen be the
                length in octets of T.
     
            2.  If emLen < tLen + 11, output "intended encoded message length
                too short" and stop.
     
            3.  Generate an octet string PS consisting of emLen - tLen - 3
                octets with hexadecimal value 0xff.  The length of PS will be
                at least 8 octets.
     
            4.  Concatenate PS, the DER encoding T, and other padding to form
                the encoded message EM as
     
                    EM = 0x00 || 0x01 || PS || 0x00 || T.
     
            5.  Output EM.
     
            SHA-256: (0x)30 31 30 0d 06 09 60 86 48 01 65 03 04 02 01 05 00 04 20 || H.
        */

        /*  
            1.  Encode the algorithm ID for the hash function and the hash
                value into an ASN.1 value of type DigestInfo (see
                Appendix A.2.4) with the DER, where the type DigestInfo has
                the syntax
     
                    DigestInfo ::= SEQUENCE {
                        digestAlgorithm AlgorithmIdentifier,
                        digest OCTET STRING
                    }
     
                The first field identifies the hash function and the second
                contains the hash value.  Let T be the DER encoding of the
                DigestInfo value (see the notes below), and let tLen be the
                length in octets of T.
     
            2.  If emLen < tLen + 11, output "intended encoded message length
                too short" and stop.
     
            3.  Generate an octet string PS consisting of emLen - tLen - 3
                octets with hexadecimal value 0xff.  The length of PS will be
                at least 8 octets.
     
            4.  Concatenate PS, the DER encoding T, and other padding to form
                the encoded message EM as
     
                    EM = 0x00 || 0x01 || PS || 0x00 || T.
     
            5.  Output EM.
     
            SHA-256: (0x)30 31 30 0d 06 09 60 86 48 01 65 03 04 02 01 05 00 04 20 || H.
        */

        uint256 PS_ByteLen = k - 54; //k - 19 - 32 - 3, 32: SHA-256 hash length
        uint256 _cursor;
        assembly ("memory-safe") {
            // inline RSAVP1 begin
            /* 
               b.  Apply the RSAVP1 verification primitive (Section 5.2.2) to
                   the RSA public key (n, e) and the signature representative
                   s to produce an integer message representative m:
                   m = RSAVP1 ((n, e), s).
                   If RSAVP1 outputs "signature representative out of range",output "invalid signature" and stop.
            */

            // bytes memory EM = RSAVP1(n, e, S);

            let EM
            {
                /*
                    Steps:
            
                    1.  If the signature representative s is not between 0 and n - 1,
                        output "signature representative out of range" and stop.
            
                    2.  Let m = s^e mod n.
            
                    3.  Output m.
                */

                // To simplify the calculations, k must be an integer multiple of 32.
                if mod(k, 0x20) {
                    mstore(0x00, false)
                    return(0x00, 0x20)
                }
                let _k := div(k, 0x20)
                for { let i := 0 } lt(i, _k) { i := add(i, 0x01) } {
                    // 1. If the signature representative S is not between 0 and n - 1, output "signature representative out of range" and stop.
                    let _n := mload(add(add(n, 0x20), mul(i, 0x20)))
                    let _s := mload(add(add(S, 0x20), mul(i, 0x20)))
                    if lt(_s, _n) {
                        // break
                        i := k
                    }
                    if gt(_s, _n) {
                        // signature representative out of range
                        mstore(0x00, false)
                        return(0x00, 0x20)
                    }
                    if eq(_s, _n) {
                        if eq(i, sub(_k, 0x01)) {
                            // signature representative out of range
                            mstore(0x00, false)
                            return(0x00, 0x20)
                        }
                    }
                }
                // 2.  Let m = s^e mod n.
                let e_length := mload(e)
                EM := mload(0x40)
                mstore(EM, k)
                mstore(add(EM, 0x20), e_length)
                mstore(add(EM, 0x40), k)
                let _cursor_inline := add(EM, 0x60)
                // copy s begin
                for { let i := 0 } lt(i, k) { i := add(i, 0x20) } {
                    mstore(_cursor_inline, mload(add(add(S, 0x20), i)))
                    _cursor_inline := add(_cursor_inline, 0x20)
                }
                // copy s end

                // copy e begin
                // To simplify the calculations, e must be an integer multiple of 32.
                if mod(e_length, 0x20) {
                    mstore(0x00, false)
                    return(0x00, 0x20)
                }
                for { let i := 0 } lt(i, e_length) { i := add(i, 0x20) } {
                    mstore(_cursor_inline, mload(add(add(e, 0x20), i)))
                    _cursor_inline := add(_cursor_inline, 0x20)
                }
                // copy e end

                // copy n begin
                for { let i := 0 } lt(i, k) { i := add(i, 0x20) } {
                    mstore(_cursor_inline, mload(add(add(n, 0x20), i)))
                    _cursor_inline := add(_cursor_inline, 0x20)
                }
                // copy n end

                // Call the precompiled contract 0x05 = ModExp
                if iszero(staticcall(not(0), 0x05, EM, _cursor_inline, add(EM, 0x20), k)) {
                    mstore(0x00, false)
                    return(0x00, 0x20)
                }
                mstore(EM, k)
                mstore(0x40, add(add(EM, 0x20), k))
            }

            // inline RSAVP1 end

            if sub(mload(add(EM, 0x20)), 0x0001ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) {
                //                             |_______________________ 0x1E bytes _______________________|

                mstore(0x00, false)
                return(0x00, 0x20)
            }
            let paddingLen := sub(PS_ByteLen, 0x1E)
            let _times := div(paddingLen, 0x20)
            _cursor := add(EM, 0x40)
            for { let i := 0 } lt(i, _times) { i := add(i, 1) } {
                if sub(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, mload(_cursor)) {
                    mstore(0x00, false)
                    return(0x00, 0x20)
                }
                _cursor := add(_cursor, 0x20)
            }
            let _remainder := mod(paddingLen, 0x20)
            if _remainder {
                let _shift := mul(0x08, sub(0x20, _remainder))
                if sub(
                    0x0000000000000000000000000000000000000000000000000000000000000000,
                    shl(_shift, not(shr(_shift, mload(_cursor))))
                ) {
                    mstore(0x00, false)
                    return(0x00, 0x20)
                }
            }

            // SHA-256 T : (0x)30 31 30 0d 06 09 60 86 48 01 65 03 04 02 01 05 00 04 20 || H.
            // EM = 0x00 || 0x01 || PS || 0x00 || T.
            _cursor := add(EM, add(0x22, PS_ByteLen /* 0x20+1+1+PS_ByteLen */ ))
            // 0x003031300d060960864801650304020105000420
            // |______________ 0x14 bytes _______________|
            if sub(0x003031300d060960864801650304020105000420, shr(0x60, /* 8*12 */ mload(_cursor))) {
                mstore(0x00, false)
                return(0x00, 0x20)
            }
        }
        assembly ("memory-safe") {
            if sub(H, mload(add(_cursor, 0x14))) {
                mstore(0x00, false)
                return(0x00, 0x20)
            }
        }
        return true;
    }

    /**
     *
     * @param n signer's RSA public key - n
     * @param e signer's RSA public key - e
     * @param M message whose signature is to be verified, an octet string
     * @param S signature to be verified, an octet string of length k, where k is the length in octets of the RSA modulus n
     */
    function RSASSA_PSS_VERIFY(bytes memory n, bytes memory e, bytes memory M, bytes memory S)
        internal
        view
        returns (bool)
    {
        uint256 k = n.length;
        // 1. Length checking: If the length of S is not k octets, output "invalid signature" and stop.
        if (k != S.length) {
            return false;
        }

        // 2. RSA verification:
        /* 
                a.  Convert the signature S to an integer signature representative s (see Section 4.2):
                    s = OS2IP (S).
        */
        /*
            c.  Convert the message representative m to an encoded message
                  EM of length k octets (see Section 4.1):
                     EM = I2OSP (m, k).
        */

        // bytes memory EM = m;

        /*  
            1.  Encode the algorithm ID for the hash function and the hash
                value into an ASN.1 value of type DigestInfo (see
                Appendix A.2.4) with the DER, where the type DigestInfo has
                the syntax
     
                    DigestInfo ::= SEQUENCE {
                        digestAlgorithm AlgorithmIdentifier,
                        digest OCTET STRING
                    }
     
                The first field identifies the hash function and the second
                contains the hash value.  Let T be the DER encoding of the
                DigestInfo value (see the notes below), and let tLen be the
                length in octets of T.
     
            2.  If emLen < tLen + 11, output "intended encoded message length
                too short" and stop.
     
            3.  Generate an octet string PS consisting of emLen - tLen - 3
                octets with hexadecimal value 0xff.  The length of PS will be
                at least 8 octets.
     
            4.  Concatenate PS, the DER encoding T, and other padding to form
                the encoded message EM as
     
                    EM = 0x00 || 0x01 || PS || 0x00 || T.
     
            5.  Output EM.
     
            SHA-256: (0x)30 31 30 0d 06 09 60 86 48 01 65 03 04 02 01 05 00 04 20 || H.
        */

        /*  
            1.  Encode the algorithm ID for the hash function and the hash
                value into an ASN.1 value of type DigestInfo (see
                Appendix A.2.4) with the DER, where the type DigestInfo has
                the syntax
     
                    DigestInfo ::= SEQUENCE {
                        digestAlgorithm AlgorithmIdentifier,
                        digest OCTET STRING
                    }
     
                The first field identifies the hash function and the second
                contains the hash value.  Let T be the DER encoding of the
                DigestInfo value (see the notes below), and let tLen be the
                length in octets of T.
     
            2.  If emLen < tLen + 11, output "intended encoded message length
                too short" and stop.
     
            3.  Generate an octet string PS consisting of emLen - tLen - 3
                octets with hexadecimal value 0xff.  The length of PS will be
                at least 8 octets.
     
            4.  Concatenate PS, the DER encoding T, and other padding to form
                the encoded message EM as
     
                    EM = 0x00 || 0x01 || PS || 0x00 || T.
     
            5.  Output EM.
     
            SHA-256: (0x)30 31 30 0d 06 09 60 86 48 01 65 03 04 02 01 05 00 04 20 || H.
        */

        uint256 PS_ByteLen = k - 54; //k - 19 - 32 - 3, 32: SHA-256 hash length
        uint256 _cursor;
        assembly ("memory-safe") {
            // inline RSAVP1 begin
            /* 
               b.  Apply the RSAVP1 verification primitive (Section 5.2.2) to
                   the RSA public key (n, e) and the signature representative
                   s to produce an integer message representative m:
                   m = RSAVP1 ((n, e), s).
                   If RSAVP1 outputs "signature representative out of range",output "invalid signature" and stop.
            */

            // bytes memory EM = RSAVP1(n, e, S);

            let EM
            {
                /*
                    Steps:
            
                    1.  If the signature representative s is not between 0 and n - 1,
                        output "signature representative out of range" and stop.
            
                    2.  Let m = s^e mod n.
            
                    3.  Output m.
                */

                // To simplify the calculations, k must be an integer multiple of 32.
                if mod(k, 0x20) {
                    mstore(0x00, false)
                    return(0x00, 0x20)
                }
                let _k := div(k, 0x20)
                for { let i := 0 } lt(i, _k) { i := add(i, 0x01) } {
                    // 1. If the signature representative S is not between 0 and n - 1, output "signature representative out of range" and stop.
                    let _n := mload(add(add(n, 0x20), mul(i, 0x20)))
                    let _s := mload(add(add(S, 0x20), mul(i, 0x20)))
                    if lt(_s, _n) {
                        // break
                        i := k
                    }
                    if gt(_s, _n) {
                        // signature representative out of range
                        mstore(0x00, false)
                        return(0x00, 0x20)
                    }
                    if eq(_s, _n) {
                        if eq(i, sub(_k, 0x01)) {
                            // signature representative out of range
                            mstore(0x00, false)
                            return(0x00, 0x20)
                        }
                    }
                }
                // 2.  Let m = s^e mod n.
                let e_length := mload(e)
                EM := mload(0x40)
                mstore(EM, k)
                mstore(add(EM, 0x20), e_length)
                mstore(add(EM, 0x40), k)
                let _cursor_inline := add(EM, 0x60)
                // copy s begin
                for { let i := 0 } lt(i, k) { i := add(i, 0x20) } {
                    mstore(_cursor_inline, mload(add(add(S, 0x20), i)))
                    _cursor_inline := add(_cursor_inline, 0x20)
                }
                // copy s end

                // copy e begin
                // To simplify the calculations, e must be an integer multiple of 32.
                if mod(e_length, 0x20) {
                    mstore(0x00, false)
                    return(0x00, 0x20)
                }
                for { let i := 0 } lt(i, e_length) { i := add(i, 0x20) } {
                    mstore(_cursor_inline, mload(add(add(e, 0x20), i)))
                    _cursor_inline := add(_cursor_inline, 0x20)
                }
                // copy e end

                // copy n begin
                for { let i := 0 } lt(i, k) { i := add(i, 0x20) } {
                    mstore(_cursor_inline, mload(add(add(n, 0x20), i)))
                    _cursor_inline := add(_cursor_inline, 0x20)
                }
                // copy n end

                // Call the precompiled contract 0x05 = ModExp
                if iszero(staticcall(not(0), 0x05, EM, _cursor_inline, add(EM, 0x20), k)) {
                    mstore(0x00, false)
                    return(0x00, 0x20)
                }
                mstore(EM, k)
                mstore(0x40, add(add(EM, 0x20), k))
            }

            // inline RSAVP1 end

            if sub(mload(add(EM, 0x20)), 0x0001ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) {
                //                             |_______________________ 0x1E bytes _______________________|

                mstore(0x00, false)
                return(0x00, 0x20)
            }
            let paddingLen := sub(PS_ByteLen, 0x1E)
            let _times := div(paddingLen, 0x20)
            _cursor := add(EM, 0x40)
            for { let i := 0 } lt(i, _times) { i := add(i, 1) } {
                if sub(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, mload(_cursor)) {
                    mstore(0x00, false)
                    return(0x00, 0x20)
                }
                _cursor := add(_cursor, 0x20)
            }
            let _remainder := mod(paddingLen, 0x20)
            if _remainder {
                let _shift := mul(0x08, sub(0x20, _remainder))
                if sub(
                    0x0000000000000000000000000000000000000000000000000000000000000000,
                    shl(_shift, not(shr(_shift, mload(_cursor))))
                ) {
                    mstore(0x00, false)
                    return(0x00, 0x20)
                }
            }

            // SHA-256 T : (0x)30 31 30 0d 06 09 60 86 48 01 65 03 04 02 01 05 00 04 20 || H.
            // EM = 0x00 || 0x01 || PS || 0x00 || T.
            _cursor := add(EM, add(0x22, PS_ByteLen /* 0x20+1+1+PS_ByteLen */ ))
            // 0x003031300d060960864801650304020105000420
            // |______________ 0x14 bytes _______________|
            if sub(0x003031300d060960864801650304020105000420, shr(0x60, /* 8*12 */ mload(_cursor))) {
                mstore(0x00, false)
                return(0x00, 0x20)
            }
        }
        bytes32 H = sha256(M);
        assembly ("memory-safe") {
            if sub(H, mload(add(_cursor, 0x14))) {
                mstore(0x00, false)
                return(0x00, 0x20)
            }
        }
        return true;
    }
}
