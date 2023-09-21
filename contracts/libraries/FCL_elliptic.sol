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
pragma solidity ^0.8.17;

library FCL_Elliptic_ZZ {
    // Set parameters for curve sec256r1.

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
    /* p - gy */
    uint256 constant gy_subtractedfrom_p = 0xB01CBD1C01E58065711814B583F061E9D431CCA994CEA1313449BF97C840AE0A;
    /* p - gx */
    uint256 constant gx_subtractedfrom_p = 0x94E82E0C1ED3BDB90743191A9C5BBF0D88FC827FD214CC5F0B5EC6BA27673D69;

    /**
     * inversion mod n via a^(n-2), use of precompiled using little Fermat theorem
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
     * inversion mod nusing little Fermat theorem via a^(n-2), use of precompiled
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

            // Call the precompiled contract 0x05 = ModExp
            if iszero(staticcall(not(0), 0x05, pointer, 0xc0, pointer, 0x20)) { revert(0, 0) }
            result := mload(pointer)
        }
    }

    /**
     * @dev Check if a point in affine coordinates is on the curve (reject Neutral that is indeed on the curve).
     */
    function ecAff_isOnCurve(uint256 x, uint256 y) internal pure returns (bool onCurve) {
        assembly {
            /*
                if (0 == x || x == p || 0 == y || y == p) {
                    return false;
                }
             */
            if or(iszero(and(x, y)), or(eq(x, p), eq(y, p))) { return(0, 0) }

            let LHS := mulmod(y, y, p) // y^2
            let RHS := addmod(mulmod(mulmod(x, x, p), x, p), mulmod(x, a, p), p) // x^3+ax
            RHS := addmod(RHS, b, p) // x^3 + a*x + b
            onCurve := eq(LHS, RHS)
        }
    }

    function ecAff_add_affinepoint(uint256 x1, uint256 y1) internal view returns (uint256 _x1, uint256 _y1) {
        assembly {
            let _x, _y, _zz, _zzz
            {
                let _y2 := addmod(mulmod(y1, 1, p), gy_subtractedfrom_p, p)
                let _x2 := addmod(mulmod(x1, 1, p), gx_subtractedfrom_p, p)
                _x := mulmod(_x2, _x2, p) //PP = P^2
                _y := mulmod(_x, _x2, p) //PPP = P*PP
                _zz := mulmod(1, _x, p) ////ZZ3 = ZZ1*PP
                _zzz := mulmod(1, _y, p) ////ZZZ3 = ZZZ1*PPP
                let _zz1 := mulmod(gx, _x, p) //Q = X1*PP
                _x := addmod(addmod(mulmod(_y2, _y2, p), sub(p, _y), p), mulmod(minus_2, _zz1, p), p) //R^2-PPP-2*Q
                _y := addmod(mulmod(addmod(_zz1, sub(p, _x), p), _y2, p), mulmod(gy_subtractedfrom_p, _y, p), p) //R*(Q-X3)
            }
            let zzzInv
            {
                let T := mload(0x40)
                // store data
                // Bsize: [0; 31]
                mstore(T, 0x20)
                // Esize: [32; 63]
                mstore(add(T, 0x20), 0x20)
                // Msize: [64; 95]
                mstore(add(T, 0x40), 0x20)
                // B: [96; 127]
                mstore(add(T, 0x60), _zzz)
                // E: [128; 159]
                mstore(add(T, 0x80), minus_2)
                // M: [160; 191]
                mstore(add(T, 0xa0), p)

                // Call the precompiled contract 0x05 = ModExp
                if iszero(staticcall(not(0), 0x05, T, 0xc0, T, 0x20)) { revert(0, 0) }
                zzzInv := mload(T)
            }
            _y1 := mulmod(_y, zzzInv, p) //Y/zzz
            zzzInv := mulmod(_zz, zzzInv, p) //1/z
            zzzInv := mulmod(zzzInv, zzzInv, p) //1/zz
            _x1 := mulmod(_x, zzzInv, p) //X/zz
        }
    }

    /**
     * @dev Computation of uG+vQ using Strauss-Shamir's trick, G basepoint, Q public key
     */
    function ecZZ_mulmuladd_S_asm(
        uint256 Qx,
        uint256 Qy, //affine rep for input point Q
        uint256 scalar_u,
        uint256 scalar_v
    ) internal view returns (uint256) {
        uint256 X;
        uint256 zz;
        {
            uint256 zzz;
            uint256 Y;
            uint256 index = 255;
            uint256 H0;
            uint256 H1;

            //(H0,H1 )=ecAff_add(gx,gy,Q0, Q1);//will not work if Q=P, obvious forbidden private key
            (H0, H1) = ecAff_add_affinepoint(Qx, Qy);

            assembly {
                // if(scalar_u==0 && scalar_v==0) return 0;
                if and(eq(scalar_u, 0), eq(scalar_v, 0)) { return(X, 0x20) }
                /*
                    while( ( ((scalar_u>>index)&1)+2*((scalar_v>>index)&1) ) ==0){
                    index=index-1; 
                    }
                */
                for { zz := add(shl(1, and(shr(index, scalar_v), 1)), and(shr(index, scalar_u), 1)) } eq(zz, 0) {
                    index := sub(index, 1)
                    zz := add(shl(1, and(shr(index, scalar_v), 1)), and(shr(index, scalar_u), 1))
                } {}

                if eq(zz, 1) {
                    X := gx
                    Y := gy
                }
                if eq(zz, 2) {
                    X := Qx
                    Y := Qy
                }
                if eq(zz, 3) {
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
                    //T2:=mulmod(T4,addmod(T3, sub(p, X),p),p)//M(S-X3)
                    T2 := mulmod(T4, addmod(X, sub(p, T3), p), p) //-M(S-X3)=M(X3-S)

                    //Y:= addmod(T2, sub(p, mulmod(T1, Y ,p)),p  )//Y3= M(S-X3)-W*Y1
                    Y := addmod(mulmod(T1, Y, p), T2, p) //-Y3= W*Y1-M(S-X3), we replace Y by -Y to avoid a sub in ecAdd

                    //value of dibit
                    T4 := add(shl(1, and(shr(index, scalar_v), 1)), and(shr(index, scalar_u), 1))

                    if iszero(T4) {
                        Y := sub(p, Y) //restore the -Y inversion
                        continue
                    } // if T4!=0

                    if eq(T4, 1) {
                        T1 := gx
                        T2 := gy
                    }
                    if eq(T4, 2) {
                        T1 := Qx
                        T2 := Qy
                    }
                    if eq(T4, 3) {
                        T1 := H0
                        T2 := H1
                    }
                    if eq(zz, 0) {
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
                    if eq(y2, 0) {
                        if eq(T2, 0) {
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
            }
        }

        assembly {
            /* 
                get free memory pointer, but no need update free memory pointer(saving 15 gas)): 
                'mstore(0x40, add(T, 0xc0))'
                because we will return X, and T is a local variable.
            */
            let T := mload(0x40)

            // store data
            // Bsize: [0; 31]
            mstore(T, 0x20)
            // Esize: [32; 63]
            mstore(add(T, 0x20), 0x20)
            // Msize: [64; 95]
            mstore(add(T, 0x40), 0x20)
            // B: [96; 127]
            mstore(add(T, 0x60), zz)
            // E: [128; 159]
            mstore(add(T, 0x80), minus_2)
            // M: [160; 191]
            mstore(add(T, 0xa0), p)

            // Call the precompiled contract 0x05 = ModExp
            if iszero(staticcall(not(0), 0x05, T, 0xc0, T, 0x20)) { revert(0, 0) }

            //Y:=mulmod(Y,zzz,p)//Y/zzz
            //zz :=mulmod(zz, mload(T),p) //1/z
            //zz:= mulmod(zz,zz,p) //1/zz
            X := mulmod(X, mload(T), p) //X/zz
        }

        return X;
    }

    /**
     * @dev ECDSA verification, given , signature, and public key.
     */
    function ecdsa_verify(bytes32 message, uint256 r, uint256 s, uint256 Qx, uint256 Qy) internal view returns (bool) {
        assembly {
            /* 
             if (r == 0 || r >= n || s == 0 || s >= n) {
                return false;
             }
             */
            if or(iszero(and(r, s)), eq(and(gt(n, r), gt(n, s)), 0)) { revert(0, 0) }
        }

        if (!ecAff_isOnCurve(Qx, Qy)) {
            return false;
        }

        uint256 sInv = FCL_nModInv(s);

        uint256 scalar_u = mulmod(uint256(message), sInv, n);
        uint256 scalar_v = mulmod(r, sInv, n);
        uint256 x1;

        x1 = ecZZ_mulmuladd_S_asm(Qx, Qy, scalar_u, scalar_v);

        assembly {
            x1 := addmod(x1, sub(n, r), n)
        }
        //return true;
        return x1 == 0;
    }
}
