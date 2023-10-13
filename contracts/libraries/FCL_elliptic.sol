//********************************************************************************************/
//  ___           _       ___               _         _    _ _
// | __| _ ___ __| |_    / __|_ _ _  _ _ __| |_ ___  | |  (_) |__
// | _| '_/ -_|_-< ' \  | (__| '_| || | '_ \  _/ _ \ | |__| | '_ \
// |_||_| \___/__/_||_|  \___|_|  \_, | .__/\__\___/ |____|_|_.__/
//                                |__/|_|
///* Copyright (C) 2022 - Renaud Dubois - This file is part of FCL (Fresh CryptoLib) project
///* License: This software is licensed under MIT License
///* This Code may be reused including license and copyright notice.
///* See LICENSE file at the root folder of the project.
///* FILE: FCL_elliptic.sol
///*
///*
///* DESCRIPTION: modified XYZZ system coordinates for EVM elliptic point multiplication
///*  optimization
///*
//**************************************************************************************/
//* WARNING: this code SHALL not be used for non prime order curves for security reasons.
// Code is optimized for a=-3 only curves with prime order, constant like -1, -2 shall be replaced
// if ever used for other curve than sec256R1
// reference: https://github.com/rdubois-crypto/FreshCryptoLib/blob/master/solidity/src/FCL_elliptic.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library FCL_Elliptic_ZZ {
    // Set parameters for curve sec256r1.

    // address of the ModExp precompiled contract (Arbitrary-precision exponentiation under modulo)
    address constant MODEXP_PRECOMPILE = 0x0000000000000000000000000000000000000005;
    //curve prime field modulus
    uint256 constant p = 0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF;
    //short weierstrass first coefficient
    uint256 constant a = 0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFC;
    //short weierstrass second coefficient
    uint256 constant b = 0x5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B;
    //generating point affine coordinates
    uint256 constant gx = 0x6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296;
    uint256 constant gy = 0x4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5;
    //curve order (number of points)
    uint256 constant n = 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551;
    /* -2 mod p constant, used to speed up inversion and doubling (avoid negation)*/
    uint256 constant minus_2 = 0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFD;
    /* -2 mod n constant, used to speed up inversion*/
    uint256 constant minus_2modn = 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC63254F;

    uint256 constant minus_1 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    //P+1 div 4
    uint256 constant pp1div4 = 0x3fffffffc0000000400000000000000000000000400000000000000000000000;
    //arbitrary constant to express no quadratic residuosity
    uint256 constant _NOTSQUARE = 0xFFFFFFFF00000002000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF;
    uint256 constant _NOTONCURVE = 0xFFFFFFFF00000003000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF;

    /**
     * /* inversion mod n via a^(n-2), use of precompiled using little Fermat theorem
     */
    function FCL_nModInv(uint256 u) internal view returns (uint256 result) {
        assembly {
            let pointer := mload(0x40)
            // Define length of base, exponent and modulus. 0x20 == 32 bytes
            mstore(pointer, 0x20)
            mstore(add(pointer, 0x20), 0x20)
            mstore(add(pointer, 0x40), 0x20)
            // Define variables base, exponent and modulus
            mstore(add(pointer, 0x60), u)
            mstore(add(pointer, 0x80), minus_2modn)
            mstore(add(pointer, 0xa0), n)

            // Call the precompiled contract 0x05 = ModExp
            if iszero(staticcall(not(0), 0x05, pointer, 0xc0, pointer, 0x20)) { revert(0, 0) }
            result := mload(pointer)
        }
    }
    /**
     * /* @dev inversion mod nusing little Fermat theorem via a^(n-2), use of precompiled
     */

    function FCL_pModInv(uint256 u) internal view returns (uint256 result) {
        assembly {
            let pointer := mload(0x40)
            // Define length of base, exponent and modulus. 0x20 == 32 bytes
            mstore(pointer, 0x20)
            mstore(add(pointer, 0x20), 0x20)
            mstore(add(pointer, 0x40), 0x20)
            // Define variables base, exponent and modulus
            mstore(add(pointer, 0x60), u)
            mstore(add(pointer, 0x80), minus_2)
            mstore(add(pointer, 0xa0), p)

            // Call the precompiled contract 0x05 = ModExp ̰
            if iszero(staticcall(not(0), 0x05, pointer, 0xc0, pointer, 0x20)) { revert(0, 0) }
            result := mload(pointer)
        }
    }

    /**
     * /* @dev Convert from XYZZ rep to affine rep
     */
    /*    https://hyperelliptic.org/EFD/g1p/auto-shortw-xyzz-3.html#addition-add-2008-s*/
    function ecZZ_SetAff(uint256 x, uint256 y, uint256 zz, uint256 zzz)
        internal
        view
        returns (uint256 x1, uint256 y1)
    {
        uint256 zzzInv = FCL_pModInv(zzz); //1/zzz
        y1 = mulmod(y, zzzInv, p); //Y/zzz
        uint256 _b = mulmod(zz, zzzInv, p); //1/z
        zzzInv = mulmod(_b, _b, p); //1/zz
        x1 = mulmod(x, zzzInv, p); //X/zz
    }

    /**
     * @dev Sutherland2008 add a ZZ point with a normalized point and greedy formulae
     * warning: assume that P1(x1,y1)!=P2(x2,y2), true in multiplication loop with prime order (cofactor 1)
     */

    function ecZZ_AddN(uint256 x1, uint256 y1, uint256 zz1, uint256 zzz1, uint256 x2, uint256 y2)
        internal
        pure
        returns (uint256 P0, uint256 P1, uint256 P2, uint256 P3)
    {
        unchecked {
            if (y1 == 0) {
                return (x2, y2, 1, 1);
            }

            assembly {
                y1 := sub(p, y1)
                y2 := addmod(mulmod(y2, zzz1, p), y1, p)
                x2 := addmod(mulmod(x2, zz1, p), sub(p, x1), p)
                P0 := mulmod(x2, x2, p) //PP = P^2
                P1 := mulmod(P0, x2, p) //PPP = P*PP
                P2 := mulmod(zz1, P0, p) ////ZZ3 = ZZ1*PP
                P3 := mulmod(zzz1, P1, p) ////ZZZ3 = ZZZ1*PPP
                zz1 := mulmod(x1, P0, p) //Q = X1*PP
                P0 := addmod(addmod(mulmod(y2, y2, p), sub(p, P1), p), mulmod(minus_2, zz1, p), p) //R^2-PPP-2*Q
                P1 := addmod(mulmod(addmod(zz1, sub(p, P0), p), y2, p), mulmod(y1, P1, p), p) //R*(Q-X3)
            }
            //end assembly
        } //end unchecked
        return (P0, P1, P2, P3);
    }

    /**
     * @dev Check if the curve is the zero curve in affine rep.
     */
    // uint256 x, uint256 y)
    function ecAff_IsZero(uint256, uint256 y) internal pure returns (bool flag) {
        return (y == 0);
    }

    /**
     * @dev Check if a point in affine coordinates is on the curve (reject Neutral that is indeed on the curve).
     */
    function ecAff_isOnCurve(uint256 x, uint256 y) internal pure returns (bool) {
        if (0 == x || x == p || 0 == y || y == p) {
            return false;
        }
        unchecked {
            uint256 LHS = mulmod(y, y, p); // y^2
            uint256 RHS = addmod(mulmod(mulmod(x, x, p), x, p), mulmod(x, a, p), p); // x^3+ax
            RHS = addmod(RHS, b, p); // x^3 + a*x + b

            return LHS == RHS;
        }
    }

    /**
     * @dev Add two elliptic curve points in affine coordinates.
     */

    function ecAff_add(uint256 x0, uint256 y0, uint256 x1, uint256 y1) internal view returns (uint256, uint256) {
        uint256 zz0;
        uint256 zzz0;

        if (ecAff_IsZero(x0, y0)) return (x1, y1);
        if (ecAff_IsZero(x1, y1)) return (x0, y0);

        (x0, y0, zz0, zzz0) = ecZZ_AddN(x0, y0, 1, 1, x1, y1);

        return ecZZ_SetAff(x0, y0, zz0, zzz0);
    }

    /**
     * @dev Computation of uG+vQ using Strauss-Shamir's trick, G basepoint, Q public key
     *       Returns only x for ECDSA use
     *
     */
    function ecZZ_mulmuladd_S_asm(
        uint256 Q0,
        uint256 Q1, //affine rep for input point Q
        uint256 scalar_u,
        uint256 scalar_v
    ) internal view returns (uint256 X) {
        uint256 zz;
        uint256 zzz;
        uint256 Y;
        uint256 index = 255;
        uint256 H0;
        uint256 H1;

        unchecked {
            if (scalar_u == 0 && scalar_v == 0) return 0;

            (H0, H1) = ecAff_add(gx, gy, Q0, Q1); //will not work if Q=P, obvious forbidden private key

            assembly {
                for { let T4 := add(shl(1, and(shr(index, scalar_v), 1)), and(shr(index, scalar_u), 1)) } eq(T4, 0) {
                    index := sub(index, 1)
                    T4 := add(shl(1, and(shr(index, scalar_v), 1)), and(shr(index, scalar_u), 1))
                } {}
                zz := add(shl(1, and(shr(index, scalar_v), 1)), and(shr(index, scalar_u), 1))

                switch zz
                case 1 {
                    X := gx
                    Y := gy
                }
                case 2 {
                    X := Q0
                    Y := Q1
                }
                case 3 {
                    X := H0
                    Y := H1
                }

                index := sub(index, 1)
                zz := 1
                zzz := 1

                for {} gt(minus_1, index) { index := sub(index, 1) } {
                    // inlined EcZZ_Dbl
                    let T1 := mulmod(2, Y, p) //U = 2*Y1, y free
                    let T2 := mulmod(T1, T1, p) // V=U^2
                    let T3 := mulmod(X, T2, p) // S = X1*V
                    T1 := mulmod(T1, T2, p) // W=UV
                    let T4 := mulmod(3, mulmod(addmod(X, sub(p, zz), p), addmod(X, zz, p), p), p) //M=3*(X1-ZZ1)*(X1+ZZ1)
                    zzz := mulmod(T1, zzz, p) //zzz3=W*zzz1
                    zz := mulmod(T2, zz, p) //zz3=V*ZZ1, V free

                    X := addmod(mulmod(T4, T4, p), mulmod(minus_2, T3, p), p) //X3=M^2-2S
                    T2 := mulmod(T4, addmod(X, sub(p, T3), p), p) //-M(S-X3)=M(X3-S)
                    Y := addmod(mulmod(T1, Y, p), T2, p) //-Y3= W*Y1-M(S-X3), we replace Y by -Y to avoid a sub in ecAdd

                    {
                        //value of dibit
                        T4 := add(shl(1, and(shr(index, scalar_v), 1)), and(shr(index, scalar_u), 1))

                        if iszero(T4) {
                            Y := sub(p, Y) //restore the -Y inversion
                            continue
                        } // if T4!=0

                        switch T4
                        case 1 {
                            T1 := gx
                            T2 := gy
                        }
                        case 2 {
                            T1 := Q0
                            T2 := Q1
                        }
                        case 3 {
                            T1 := H0
                            T2 := H1
                        }
                        if iszero(zz) {
                            X := T1
                            Y := T2
                            zz := 1
                            zzz := 1
                            continue
                        }
                        // inlined EcZZ_AddN

                        //T3:=sub(p, Y)
                        //T3:=Y
                        let y2 := addmod(mulmod(T2, zzz, p), Y, p) //R
                        T2 := addmod(mulmod(T1, zz, p), sub(p, X), p) //P

                        //special extremely rare case accumulator where EcAdd is replaced by EcDbl, no need to optimize this
                        //todo : construct edge vector case
                        if iszero(y2) {
                            if iszero(T2) {
                                T1 := mulmod(minus_2, Y, p) //U = 2*Y1, y free
                                T2 := mulmod(T1, T1, p) // V=U^2
                                T3 := mulmod(X, T2, p) // S = X1*V

                                let TT1 := mulmod(T1, T2, p) // W=UV
                                y2 := addmod(X, zz, p)
                                TT1 := addmod(X, sub(p, zz), p)
                                y2 := mulmod(y2, TT1, p) //(X-ZZ)(X+ZZ)
                                T4 := mulmod(3, y2, p) //M

                                zzz := mulmod(TT1, zzz, p) //zzz3=W*zzz1
                                zz := mulmod(T2, zz, p) //zz3=V*ZZ1, V free

                                X := addmod(mulmod(T4, T4, p), mulmod(minus_2, T3, p), p) //X3=M^2-2S
                                T2 := mulmod(T4, addmod(T3, sub(p, X), p), p) //M(S-X3)

                                Y := addmod(T2, mulmod(T1, Y, p), p) //Y3= M(S-X3)-W*Y1

                                continue
                            }
                        }

                        T4 := mulmod(T2, T2, p) //PP
                        let TT1 := mulmod(T4, T2, p) //PPP, this one could be spared, but adding this register spare gas
                        zz := mulmod(zz, T4, p)
                        zzz := mulmod(zzz, TT1, p) //zz3=V*ZZ1
                        let TT2 := mulmod(X, T4, p)
                        T4 := addmod(addmod(mulmod(y2, y2, p), sub(p, TT1), p), mulmod(minus_2, TT2, p), p)
                        Y := addmod(mulmod(addmod(TT2, sub(p, T4), p), y2, p), mulmod(Y, TT1, p), p)

                        X := T4
                    }
                } //end loop
                let T := mload(0x40)
                mstore(add(T, 0x60), zz)
                //(X,Y)=ecZZ_SetAff(X,Y,zz, zzz);
                //T[0] = inverseModp_Hard(T[0], p); //1/zzz, inline modular inversion using precompile:
                // Define length of base, exponent and modulus. 0x20 == 32 bytes
                mstore(T, 0x20)
                mstore(add(T, 0x20), 0x20)
                mstore(add(T, 0x40), 0x20)
                // Define variables base, exponent and modulus
                //mstore(add(pointer, 0x60), u)
                mstore(add(T, 0x80), minus_2)
                mstore(add(T, 0xa0), p)

                // Call the precompiled contract 0x05 = ModExp
                if iszero(staticcall(not(0), 0x05, T, 0xc0, T, 0x20)) { revert(0, 0) }

                //Y:=mulmod(Y,zzz,p)//Y/zzz
                //zz :=mulmod(zz, mload(T),p) //1/z
                //zz:= mulmod(zz,zz,p) //1/zz
                X := mulmod(X, mload(T), p) //X/zz
            } //end assembly
        } //end unchecked

        return X;
    }

    /**
     * @dev ECDSA verification, given , signature, and public key.
     */
    function ecdsa_verify(bytes32 message, uint256 r, uint256 s, uint256 Q0, uint256 Q1) internal view returns (bool) {
        if (r == 0 || r >= n || s == 0 || s >= n) {
            return false;
        }
        if (!ecAff_isOnCurve(Q0, Q1)) {
            return false;
        }

        uint256 sInv = FCL_nModInv(s);

        uint256 scalar_u = mulmod(uint256(message), sInv, n);
        uint256 scalar_v = mulmod(r, sInv, n);
        uint256 x1;

        x1 = ecZZ_mulmuladd_S_asm(Q0, Q1, scalar_u, scalar_v);

        assembly {
            x1 := addmod(x1, sub(n, r), n)
        }
        //return true;
        return x1 == 0;
    }

    function ec_Decompress(uint256 x, uint256 parity) internal view returns (uint256 y) {
        uint256 y2 = mulmod(x, mulmod(x, x, p), p); //x3
        y2 = addmod(b, addmod(y2, mulmod(x, a, p), p), p); //x3+ax+b

        y = SqrtMod(y2);
        if (y == _NOTSQUARE) {
            return _NOTONCURVE;
        }
        if ((y & 1) != (parity & 1)) {
            y = p - y;
        }
    }

    /// @notice Calculate one modular square root of a given integer. Assume that p=3 mod 4.
    /// @dev Uses the ModExp precompiled contract at address 0x05 for fast computation using little Fermat theorem
    /// @param self The integer of which to find the modular inverse
    /// @return result The modular inverse of the input integer. If the modular inverse doesn't exist, it revert the tx

    function SqrtMod(uint256 self) internal view returns (uint256 result) {
        assembly ("memory-safe") {
            // load the free memory pointer value
            let pointer := mload(0x40)

            // Define length of base (Bsize)
            mstore(pointer, 0x20)
            // Define the exponent size (Esize)
            mstore(add(pointer, 0x20), 0x20)
            // Define the modulus size (Msize)
            mstore(add(pointer, 0x40), 0x20)
            // Define variables base (B)
            mstore(add(pointer, 0x60), self)
            // Define the exponent (E)
            mstore(add(pointer, 0x80), pp1div4)
            // We save the point of the last argument, it will be override by the result
            // of the precompile call in order to avoid paying for the memory expansion properly
            let _result := add(pointer, 0xa0)
            // Define the modulus (M)
            mstore(_result, p)

            // Call the precompiled ModExp (0x05) https://www.evm.codes/precompiled#0x05
            if iszero(
                staticcall(
                    not(0), // amount of gas to send
                    MODEXP_PRECOMPILE, // target
                    pointer, // argsOffset
                    0xc0, // argsSize (6 * 32 bytes)
                    _result, // retOffset (we override M to avoid paying for the memory expansion)
                    0x20 // retSize (32 bytes)
                )
            ) { revert(0, 0) }

            result := mload(_result)
            //  result :=addmod(result,0,p)
        }
        if (mulmod(result, result, p) != self) {
            result = _NOTSQUARE;
        }

        return result;
    }
    /**
     * @dev Computation of uG+vQ using Strauss-Shamir's trick, G basepoint, Q public key
     *       Returns affine representation of point (normalized)
     *
     */

    function ecZZ_mulmuladd(
        uint256 Q0,
        uint256 Q1, //affine rep for input point Q
        uint256 scalar_u,
        uint256 scalar_v
    ) internal view returns (uint256 X, uint256 Y) {
        uint256 zz;
        uint256 zzz;
        uint256 index = 255;
        uint256[2] memory H;

        unchecked {
            if (scalar_u == 0 && scalar_v == 0) return (0, 0);

            (H[0], H[1]) = ecAff_add(gx, gy, Q0, Q1); //will not work if Q=P, obvious forbidden private key

            assembly {
                for { let T4 := add(shl(1, and(shr(index, scalar_v), 1)), and(shr(index, scalar_u), 1)) } eq(T4, 0) {
                    index := sub(index, 1)
                    T4 := add(shl(1, and(shr(index, scalar_v), 1)), and(shr(index, scalar_u), 1))
                } {}
                zz := add(shl(1, and(shr(index, scalar_v), 1)), and(shr(index, scalar_u), 1))

                switch zz
                case 1 {
                    X := gx
                    Y := gy
                }
                case 2 {
                    X := Q0
                    Y := Q1
                }
                case 3 {
                    Y := mload(add(H, 32))
                    X := mload(H)
                }

                index := sub(index, 1)
                zz := 1
                zzz := 1

                for {} gt(minus_1, index) { index := sub(index, 1) } {
                    // inlined EcZZ_Dbl
                    let T1 := mulmod(2, Y, p) //U = 2*Y1, y free
                    let T2 := mulmod(T1, T1, p) // V=U^2
                    let T3 := mulmod(X, T2, p) // S = X1*V
                    T1 := mulmod(T1, T2, p) // W=UV
                    let T4 := mulmod(3, mulmod(addmod(X, sub(p, zz), p), addmod(X, zz, p), p), p) //M=3*(X1-ZZ1)*(X1+ZZ1)
                    zzz := mulmod(T1, zzz, p) //zzz3=W*zzz1
                    zz := mulmod(T2, zz, p) //zz3=V*ZZ1, V free

                    X := addmod(mulmod(T4, T4, p), mulmod(minus_2, T3, p), p) //X3=M^2-2S
                    T2 := mulmod(T4, addmod(X, sub(p, T3), p), p) //-M(S-X3)=M(X3-S)
                    Y := addmod(mulmod(T1, Y, p), T2, p) //-Y3= W*Y1-M(S-X3), we replace Y by -Y to avoid a sub in ecAdd

                    {
                        //value of dibit
                        T4 := add(shl(1, and(shr(index, scalar_v), 1)), and(shr(index, scalar_u), 1))

                        if iszero(T4) {
                            Y := sub(p, Y) //restore the -Y inversion
                            continue
                        } // if T4!=0

                        switch T4
                        case 1 {
                            T1 := gx
                            T2 := gy
                        }
                        case 2 {
                            T1 := Q0
                            T2 := Q1
                        }
                        case 3 {
                            T1 := mload(H)
                            T2 := mload(add(H, 32))
                        }

                        if iszero(zz) {
                            X := T1
                            Y := T2
                            zz := 1
                            zzz := 1
                            continue
                        }
                        // inlined EcZZ_AddN

                        //T3:=sub(p, Y)
                        //T3:=Y
                        let y2 := addmod(mulmod(T2, zzz, p), Y, p) //R
                        T2 := addmod(mulmod(T1, zz, p), sub(p, X), p) //P

                        //special extremely rare case accumulator where EcAdd is replaced by EcDbl, no need to optimize this
                        //todo : construct edge vector case
                        if iszero(y2) {
                            if iszero(T2) {
                                T1 := mulmod(minus_2, Y, p) //U = 2*Y1, y free
                                T2 := mulmod(T1, T1, p) // V=U^2
                                T3 := mulmod(X, T2, p) // S = X1*V

                                T1 := mulmod(T1, T2, p) // W=UV
                                y2 := addmod(X, zz, p) //X+ZZ
                                let TT1 := addmod(X, sub(p, zz), p) //X-ZZ
                                y2 := mulmod(y2, TT1, p) //(X-ZZ)(X+ZZ)
                                T4 := mulmod(3, y2, p) //M

                                zzz := mulmod(TT1, zzz, p) //zzz3=W*zzz1
                                zz := mulmod(T2, zz, p) //zz3=V*ZZ1, V free

                                X := addmod(mulmod(T4, T4, p), mulmod(minus_2, T3, p), p) //X3=M^2-2S
                                T2 := mulmod(T4, addmod(T3, sub(p, X), p), p) //M(S-X3)

                                Y := addmod(T2, mulmod(T1, Y, p), p) //Y3= M(S-X3)-W*Y1

                                continue
                            }
                        }

                        T4 := mulmod(T2, T2, p) //PP
                        let TT1 := mulmod(T4, T2, p) //PPP, this one could be spared, but adding this register spare gas
                        zz := mulmod(zz, T4, p)
                        zzz := mulmod(zzz, TT1, p) //zz3=V*ZZ1
                        let TT2 := mulmod(X, T4, p)
                        T4 := addmod(addmod(mulmod(y2, y2, p), sub(p, TT1), p), mulmod(minus_2, TT2, p), p)
                        Y := addmod(mulmod(addmod(TT2, sub(p, T4), p), y2, p), mulmod(Y, TT1, p), p)

                        X := T4
                    }
                } //end loop
                let T := mload(0x40)
                mstore(add(T, 0x60), zzz)
                //(X,Y)=ecZZ_SetAff(X,Y,zz, zzz);
                //T[0] = inverseModp_Hard(T[0], p); //1/zzz, inline modular inversion using precompile:
                // Define length of base, exponent and modulus. 0x20 == 32 bytes
                mstore(T, 0x20)
                mstore(add(T, 0x20), 0x20)
                mstore(add(T, 0x40), 0x20)
                // Define variables base, exponent and modulus
                //mstore(add(pointer, 0x60), u)
                mstore(add(T, 0x80), minus_2)
                mstore(add(T, 0xa0), p)

                // Call the precompiled contract 0x05 = ModExp
                if iszero(staticcall(not(0), 0x05, T, 0xc0, T, 0x20)) { revert(0, 0) }

                Y := mulmod(Y, mload(T), p) //Y/zzz
                zz := mulmod(zz, mload(T), p) //1/z
                zz := mulmod(zz, zz, p) //1/zz
                X := mulmod(X, zz, p) //X/zz
            } //end assembly
        } //end unchecked

        return (X, Y);
    }

    function ec_recover_r1(uint256 h, uint256 v, uint256 r, uint256 s) internal view returns (bytes32) {
        if (r == 0 || r >= n || s == 0 || s >= n) {
            return 0;
        }
        uint256 y = ec_Decompress(r, v - 27);
        uint256 rinv = FCL_nModInv(r);
        uint256 u1 = mulmod(n - addmod(0, h, n), rinv, n); //-hr^-1
        uint256 u2 = mulmod(s, rinv, n); //sr^-1

        uint256 Qx;
        uint256 Qy;
        (Qx, Qy) = ecZZ_mulmuladd(r, y, u1, u2);

        return keccak256(abi.encodePacked(Qx, Qy));
    }
}
