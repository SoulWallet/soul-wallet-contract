// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../entrypoint/Helpers.sol";

/**
 * @dev Signatures layout used by the Paymasters and Wallets internally
 * @param mode whether it is an owner's or a guardian's signature
 * @param values list of signatures value to validate
 */
struct SignatureData {
    SignatureMode mode;
    address signer;
    uint256 validationData;
    bytes signature;
}

/**
 * @dev Signature mode to denote whether it is an owner's or a guardian's signature
 */
enum SignatureMode {
    owner,      // 0x0
    guardians   // 0x1
}


library Signatures {
    /**
     * @dev Decode a signature from bytes
     * @param signature encoded signature data
     * @return SignatureData
     */
    function decodeSignature(
        bytes memory signature
    ) internal pure returns (SignatureData memory) {
        /*
        
            #####################################
            ############# DATA SHEET ############
            #####################################
        
            The trade-off is cost, on some L2 calldata is the main cost, So we need to make sure the packed data is as small as possible.
            But if overcompress high, more gas needed to decompress, which is not reasonable on L1.
            e.g. the signature inside DYNAMICDATA must with bytes32 data header, this does not require multiple data copies, but simply returns the data pointer.
                    
                    
            # `dynamic structure` definition:
            +--------------------------------------------------+
            |      `version`       |       `dynamic data`      |
            |----------------------+---------------------------|
            |      uint8 1byte     |             ...           |
            +--------------------------------------------------+




            # `version` 0x00: 
            +---------------------------------------------------------------------------------------------------------------+
            |                                                                                                               |
            |       # `dynamic data` definition:                                                                            |
            |       +--------------------------------------------------+                                                    |
            |       |                  `dynamic data`                  |                                                    |
            |       |------------------------+-------------------------|                                                    |
            |       |       `data type`      |         `data`          |                                                    |
            |       +------------------------+-------------------------+                                                    |
            |       |       uint8 1byte      |           ...           |                                                    |
            |       +--------------------------------------------------+                                                    |
            |                                                                                                               |
            |       # `data type` definition:                                                                               |
            |       +---------------------------------------------------------------------------------------+               |
            |       |                                 `data type` (Max:0b11111111)                          |               |
            |       +---------------------------------------------------------------------------------------+               |
            |       |   bit1   |   bit1   |   bit1   |   bit1   |   bit1   |   bit1   |   bit1   |   bit1   |               |
            |       +----------------------------------------------------------------------------+--------- +               |
            |       |                      `signatureMode`  uint7 (Max:0b1111111)                | `modeBit`|               |
            |       +---------------------------------------------------------------------------------------+               |
            |                                                                                                               |
            |       # `signatureMode` definition:                                                                           |
            |               0b0000000: owner signature                                                                      |
            |               0b0000001: guardian signature                                                                   |
            |               0b0000002 ~ 0b1111111: reserved                                                                 |
            |                                                                                                               |
            |                                                                                                               |
            |       # `modeBit` definition:                                                                                 |
            |               0b0: dynamic data without validationData ( aggregator & validAfter and validUntil )             |
            |               0b1: dynamic data with validationData ( aggregator & validAfter and validUntil )                |
            |                                                                                                               |
            |                                                                                                               |
            |       # `data` without validAfter and validUntil                                                              |
            |       +-----------------------------------------------------------------------+                               |
            |       |                              dynamicdata                              |                               |
            |       +-----------------------------------------------------------------------+                               |
            |       |         signer       |       signature (dynamic with length header)   |                               |
            |       +----------------------+------------------------------------------------+                               |
            |       |    address 20 byte   |           dynamic with length header           |                               |
            |       +-----------------------------------------------------------------------+                               |
            |                                                                                                               |
            |                                                                                                               |
            |                                                                                                               |
            |       # `dynamicdata` with validAfter and validUntil                                                          |
            |       +--------------------------------------------------------------------------------------------------+    |
            |       |                                               dynamicdata                                        |    |
            |       +--------------------------------------------------------------------------------------------------+    |
            |       |         signer       |          validationData        |  signature (dynamic with length header)  |    |
            |       +----------------------+--------------------------------+------------------------------------------+    |
            |       |    address 20 byte   |         uint256 32 bytes       |       dynamic with length header         |    |
            |       +--------------------------------------------------------------------------------------------------+    |
            |                                                                                                               |
            |       Note: `validationData` is packed into uint256,so you can return `validationData` directly to entrypoint |
            |             (no additional processing)                                                                        |
            |                                                                                                               |
            +---------------------------------------------------------------------------------------------------------------+
                
           # Compatible typescript implementations:

            enum SignatureMode {
                owner = 0x0,
                guardian = 0x1
            }

            function encodeSignature(
                signatureMode: SignatureMode,
                signer: string,
                aggregator: string,
                validAfter: number,
                validUntil: number,
                signature: string
            ) {
                const version = 0x0;

                const validationData = BigNumber.from(validUntil).shl(160)
                    .add(BigNumber.from(validAfter).shl(160 + 48))
                    .add(BigNumber.from(aggregator));

                let modeBit = 0b1;

                if (validationData.eq(0)) {
                    modeBit = 0b0;
                }

                let packedSignature = BigNumber.from(version).and(0xff).toHexString();

                // 1byte data type
                {
                    const datatype = BigNumber.from(signatureMode).shl(1).add(modeBit).and(0xff).toHexString().slice(2);
                    packedSignature = packedSignature + datatype;
                }
                // data
                {
                    if (signer.startsWith('0x')) {
                        signer = signer.slice(2);
                    }
                    let data = signer;
                    if (modeBit === 0b0) {
                        // 0b0: dynamic data without validationData
                    } else {
                        // 0b1: dynamic data with validationData
                        const _validationData = ethers.utils.hexZeroPad(ethers.utils.hexlify(validationData.toBigInt()), 32).slice(2);
                        data = data + _validationData;

                    }

                    if (signature.startsWith('0x')) {
                        signature = signature.slice(2);
                    }
                    signature = ethers.utils.hexZeroPad(
                        ethers.utils.hexlify(signature.length / 2),
                        32
                    ).slice(2) + signature;

                    data = data + signature;

                    packedSignature = packedSignature + data;

                }
                return packedSignature;
            }

            function decodeSignature(packedSignature: string) {
                if (!packedSignature.startsWith('0x')) {
                    packedSignature = '0x' + packedSignature;
                }
                const version = BigNumber.from(packedSignature.slice(0, 4));
                if (!version.eq(0)) {
                    throw new Error('invalid version');
                }
                const datatype = BigNumber.from(packedSignature.slice(4, 6));
                const modeBit = datatype.and(0b1).toNumber();
                const signatureMode = datatype.shr(1).and(0b1111111);

                const data = packedSignature.slice(6);
                const signer = '0x' + data.slice(0, 40);
                let signatureOffset = 40;
                let validAfter: BigNumber = BigNumber.from(0);
                let validUntil: BigNumber = BigNumber.from(0);
                let aggregator: string = '0x0000000000000000000000000000000000000000';
                if (modeBit === 0b0) {
                    // 0b0: dynamic data without validAfter and validUntil
                } else {
                    // 0b1: dynamic data with validAfter and validUntil
                    signatureOffset = signatureOffset + 64;
                    const validationData = BigNumber.from('0x' + data.slice(40, 40 + 64));
                    validAfter = validationData.shr(160 + 48).and(0xffffffffffff);
                    validUntil = validationData.shr(160).and(0xffffffffffff);
                    const _mask = BigNumber.from('0xffffffffffffffffffffffffffffffffffffffff');
                    aggregator = validationData.and(_mask).toHexString();
                }
                const _signature = data.slice(signatureOffset);
                const signatureLength = BigNumber.from('0x' + _signature.slice(0, 64)).toNumber();
                const signature = '0x' + _signature.slice(64, 64 + signatureLength * 2);
                return {
                    signatureMode,
                    signer,
                    aggregator,
                    validAfter,
                    validUntil,
                    signature
                };
            }
    
*/

        SignatureMode _signatureMode;
        address _signer;
        uint256 _validationData;
        bytes memory _subSignature;

        assembly {
            /*
                version: uint8  1byte
                offset: 32 `header of bytes` - (  32 ` mload 32` - 1 ` uint8 1bytes`  )
                `& 0xff to get the last byte`
             */
            let version := and(mload(add(signature, 1)), 0xff)

            switch version
            case 0 {
                // version 0x0

                /*
                    datatype:uint8  1byte
                    offset: 32 `header of bytes` - (  32 ` mload 32` - 2 ` 2 * uint8 1bytes`  )
                    & 0xff to get the last byte
                */
                let dataType := and(mload(add(signature, 2)), 0xff)
                /*
                    modeBit: uint1  1bit
                */
                let modeBit := and(dataType, 0x1)

                /*
                    signatureMode: uint7  7bit
                    0x7f = 0b01111111 (max value of uint7)
                */
                _signatureMode := and(shr(1, dataType), 0x7f)

                /*
                    data: bytes  dynamic
                    offset: 32 `header of bytes` + 2 `datatype & version 2bytes`
                */
                let data := add(signature, 0x22)

                /*
                    signer: address  20bytes 
                    offset: DYNAMICDATA - ( 32 ` mload 32` - 20 ` address 20bytes` )
                */
                _signer := and(
                    mload(sub(data, 0x0c)),
                    0xffffffffffffffffffffffffffffffffffffffff
                )

                
                let subSignatureOffset := 0x36

                /*
                    if modeBit==0x1 : validationData is packed into uint256
                */
                if eq(modeBit, 0x1) /* modeBit==1 */ {
                    /*
                        validationData: uint256  32bytes
                        offset: data + 20 ` address 20bytes`
                    */
                    _validationData := mload(add(data, 0x14))

                    subSignatureOffset := 0x56
                }

                /*
                    for security reason, must check the length of signature, avoid data overflow
                 */
                let signatureLength := mload(signature)
                let subSignatureLength := mload(add(signature, subSignatureOffset))

                // subSignatureOffset + subSignatureLength = signatureLength
                let subSignatureLengthCheck := add(subSignatureOffset, subSignatureLength)
                
                /*
                    if subSignatureLengthCheck != signatureLength, revert
                 */
                if eq(eq(subSignatureLengthCheck, signatureLength),0x0) {
                    revert(0, 0)
                }

                
                _subSignature := add(signature, subSignatureOffset)
            }
            default {
                // unknown version
                revert(0, 0)
            }
        }

        return
            SignatureData(_signatureMode, _signer, _validationData, _subSignature);
    }

    /**
     * @dev Decode validationData
     * @param validationData validationData
     */
    function decodeValidationData(
        uint256 validationData
    ) internal pure returns (ValidationData memory _validationData) {
        return _parseValidationData(validationData);
    }

    /**
     * @dev pack hash message with `signatureData.mode`,`signatureData.signer`,`signatureData.validationData`
     */
    function packSignatureHash(bytes32 hash, SignatureData memory signatureData) internal pure returns (bytes32) {
        bytes32 _hash = keccak256(abi.encodePacked(hash,signatureData.mode,signatureData.signer,signatureData.validationData));
        return _hash;
    }
}