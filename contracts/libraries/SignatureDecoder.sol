// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

library SignatureDecoder {
    /*
    
    A:
        +----------------------------------------+
        |            raw signature               |
        +----------------------------------------+
        |             length:65                  |
        +----------------------------------------+

    B:
        # `dynamic structure` definition:
        +--------------------------------------------------+
        |      `signType`      |       `dynamic data`      |
        |----------------------+---------------------------|
        |      uint8 1byte     |             ...           |
        +--------------------------------------------------+

        # `signType` 0x00:
        - EOA signature with validationData ( validAfter and validUntil )
        +----------------------------------------------------------------------+  
        |                        dynamic data                                  |  
        +----------------------------------------------------------------------+  
        |     validationData        |                   signature              |
        +---------------------------+------------------------------------------+  
        |    uint256 32 bytes       |             65 length signature          |  
        +----------------------------------------------------------------------+

        # `signType` 0x01: (Not implemented yet)
        - EIP-1271 signature without validationData
        +-----------------------------------------------------------------+
        |                        dynamic data                             |
        +-----------------------------------------------------------------+
        |         signer       |  signature (dynamic with length header)  |
        +----------------------+------------------------------------------+
        |    address 20 byte   |       dynamic with length header         |
        +-----------------------------------------------------------------+

     */

    struct SignatureData {
        uint256 validationData;
        bytes signature;
    }

    function decodeSignature(
        bytes memory signature
    ) internal pure returns (SignatureData memory) {
        if (signature.length == 65) {
            return SignatureData(0, signature);
        } else {
            uint256 _validationData;
            bytes memory _signature;
            assembly {
                /*
                    signType: uint8  1byte
                    offset: 32 `header of bytes` - (  32 ` mload 32` - 1 ` uint8 1bytes`  )
                    `& 0xff to get the last byte`
                */
                let signType := and(mload(add(signature, 1)), 0xff)
                switch signType
                case 0x0 {
                    // signType 0x0, EOA signature with validationData ( validAfter and validUntil )
                    /*
                        validationData: uint256 32bytes
                        offset: 32 `header of bytes` + 1 `signType`
                     */
                    _validationData := mload(add(signature, 33))
                    /*
                        signature: bytes
                        offset: 32 `header of bytes` + 1 `signType` + 32 `validationData`
                        length: 65 `signature length`
                     */
                    // set _signature length to 65
                    mstore(_signature, 65)
                    // copy signature to _signature
                    mstore(add(_signature, 32), mload(add(signature, 65)))
                    mstore(add(_signature, 64), mload(add(signature, 97)))
                }
                case 0x1 {
                    // signType 0x1, EIP-1271 signature withOut validationData ( validAfter and validUntil )
                    // not implemented yet
                    revert(0, 0)
                }
                default {
                    revert(0, 0)
                }
            }
            return SignatureData(_validationData, _signature);
        }
    }

    
}
