// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../entrypoint/Helpers.sol";

/**
 * @dev Signature mode to denote whether it is an owner's or a guardian's signature
 */
enum SignatureMode {
    owner, // 0
    guardians // 1
}

/**
 * @dev Signatures layout used by the Paymasters and Wallets internally
 */
struct SignatureData {
    SignatureMode mode;
    address signer;
    uint256 validationData;
    bytes signature;
}

library SignatureHelper {
    /**
     * @dev Decode a signature
     * @param signature encoded signature data
     * @return SignatureData
     */
    function decodeSignature(
        bytes memory signature
    ) internal pure returns (SignatureData memory) {
        SignatureMode _signatureMode;
        address _signer;
        uint256 _validationData;
        bytes memory _signature;
        /*
        
            #####################################
            ############# DATA SHEET ############
            #####################################
        
            The trade-off is cost, on some L2 calldata is the main cost, So we need to make sure the packed data is as small as possible.
            But if overcompress high, more gas needed to decompress, which is not reasonable on L1.
            e.g. the signature inside DYNAMICDATA must with bytes32 data header, this does not require multiple data copies, but simply returns the data pointer.
        
        
            So the `dynamic structure` is defined:
            --------------------------------------------------
           |       DATATYPE       |        DYNAMICDATA        |  
            --------------------------------------------------
           |      uint8 1byte     |             ...           |
            --------------------------------------------------
        
        
        
            The definition of `DATATYPE`:
            ---------------------------------------------------------------------------------------
           |                                  DATATYPE (Max:0b11111111)                            |  
            ---------------------------------------------------------------------------------------
           |   bit1   |   bit1   |   bit1   |   bit1   |   bit1   |   bit1   |   bit1   |   bit1   |
            --------------------------------------------------------------------------------------- 
           |                       signatureMode  uint7 (Max:0b1111111)                 |  modeBit |
            --------------------------------------------------------------------------------------- 
            
            `signatureMode` definition:
                    0b0000000: owner signature
                    0b0000001: guardian signature
                    0b0000002 ~ 0b1111111: reserved
        
        
            `modeBit` definition: 
                    0b0: dynamic data without validationData ( aggregator & validAfter and validUntil )
                    0b1: dynamic data with validationData ( aggregator & validAfter and validUntil )
        
        
                    
            # `dynamicdata` without validAfter and validUntil
            -----------------------------------------------------------------------
           |                              DYNAMICDATA                              |
            -----------------------------------------------------------------------
           |         signer       |       signature (dynamic with length header)   |
            -----------------------------------------------------------------------
           |    address 20 byte   |           dynamic with length header           |
            -----------------------------------------------------------------------
        
        
        
            # `dynamicdata` with validAfter and validUntil
            ---------------------------------------------------------------------------------------------------
           |                                               DYNAMICDATA                                         |
            ---------------------------------------------------------------------------------------------------
           |         signer       |          validationData        |  signature (dynamic with length header)   |
            ---------------------------------------------------------------------------------------------------
           |    address 20 byte   |         uint256 32 bytes       |       dynamic with length header          |
            ---------------------------------------------------------------------------------------------------
            Note: `validationData` is packed into uint256,so you can return `validationData` directly to entrypoint (no additional processing)
  
    
           # Compatible typescript implementations:
   
           function encodeSignature(
               signatureMode: SignatureMode,
               signer: string,
               validAfter: number,
               validUntil: number,
               signature: string
           ) {
               if (signature.startsWith('0x')) {
                   signature = signature.slice(2);
               }
               signature = ethers.utils.hexZeroPad(
                   ethers.utils.hexlify(signature.length / 2),
                   32
               ).slice(2) + signature;
           
               if (signer.startsWith('0x')) {
                   signer = signer.slice(2);
               }
               let modeBit = 0b1;
               if (validAfter === 0 && validUntil === 0) {
                   modeBit = 0b0;
               }
               // 1byte DATATYPE
               const DATATYPE = BigNumber.from(signatureMode).shl(1).add(modeBit).and(0xff);
               let DYNAMICDATA = signer;
               if (modeBit === 0b0) {
                   // 0b0: dynamic data without validAfter and validUntil
               } else {
                   // 0b1: dynamic data with validAfter and validUntil
                   // (uint256(validUntil) << 160) | (uint256(validAfter) << (160 + 48))
                   const packedValidTime = BigNumber.from(validUntil).shl(160).add(BigNumber.from(validAfter).shl(160 + 48));
                   DYNAMICDATA = DYNAMICDATA + ethers.utils.hexZeroPad(ethers.utils.hexlify(packedValidTime.toBigInt()), 32).slice(2);
               }
               DYNAMICDATA = DYNAMICDATA + signature;
           
               const packedSignature = DATATYPE.toHexString() + DYNAMICDATA;
               return packedSignature;
           }
           
           function decodeSignature(packedSignature: string) {
               if (!packedSignature.startsWith('0x')) {
                   packedSignature = '0x' + packedSignature;
               }
               const DATATYPE = BigNumber.from(packedSignature.slice(0, 4));
               const modeBit = DATATYPE.and(0b1).toNumber();
               const signatureMode = DATATYPE.shr(1).and(0b1111111);
               const DYNAMICDATA = packedSignature.slice(4);
               const signer = '0x' + DYNAMICDATA.slice(0, 40);
               let signatureOffset = 40;
               let validAfter: BigNumber = BigNumber.from(0);
               let validUntil: BigNumber = BigNumber.from(0);
               if (modeBit === 0b0) {
                   // 0b0: dynamic data without validAfter and validUntil
               } else {
                   // 0b1: dynamic data with validAfter and validUntil
                   signatureOffset = signatureOffset + 64;
                   const packedValidTime = BigNumber.from('0x' + DYNAMICDATA.slice(40, 40 + 64));
                   validAfter = packedValidTime.shr(160 + 48).and(0xffffffffffff);
                   validUntil = packedValidTime.shr(160).and(0xffffffffffff);
               }
               const _signature = DYNAMICDATA.slice(signatureOffset);
               const signatureLength = BigNumber.from('0x' + _signature.slice(0, 64)).toNumber();
               const signature = '0x' + _signature.slice(64, 64 + signatureLength * 2);
               return {
                   signatureMode,
                   signer,
                   validAfter,
                   validUntil,
                   signature
               };
           }

    
*/

        assembly {
            /*
             DATATYPE:uint8  1byte
             offset: 32 `header of bytes` - (  32 ` mload 32` - 1 ` uint8 1bytes`  )
             & 0xff to get the last byte
             */
            let DATATYPE := and(mload(add(signature, 1)), 0xff)

            /*
             modeBit: uint1  1bit
             */
            let modeBit := and(DATATYPE, 0x1)

            /*
             signatureMode: uint7  7bit
             0x7f = 0b01111111 (max value of uint7)
             */
            _signatureMode := and(shr(1, DATATYPE), 0x7f)

            /*
             DYNAMICDATA: bytes  dynamic
             offset: 32 `header of bytes` + 1 `DATATYPE`
             */
            let DYNAMICDATA := add(signature, 0x21)

            /*
             signer: address  20bytes 
             offset: DYNAMICDATA - ( 32 ` mload 32` - 20 ` address 20bytes` )
             */
            _signer := and(
                mload(sub(DYNAMICDATA, 0x0c)),
                0xffffffffffffffffffffffffffffffffffffffff
            )

            /*
             offset: 20 `address 20bytes`
             */
            let _signatureOffset := 0x14

            /*
              if modeBit==0x1 : validationData is packed into uint256
             */
            if eq(modeBit, 0x1) /* modeBit==1 */ {
                /*
                  packedValidTime: uint256  32bytes
                  offset: DYNAMICDATA + 20 ` address 20bytes`
                 */
                _validationData := mload(add(DYNAMICDATA, 0x14))
                _signatureOffset := 0x34 /* 32 `uint256 32bytes` + 20 `address 20bytes` */
            }
            _signature := add(DYNAMICDATA, _signatureOffset)
        }

        return
            SignatureData(_signatureMode, _signer, _validationData, _signature);
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
}
