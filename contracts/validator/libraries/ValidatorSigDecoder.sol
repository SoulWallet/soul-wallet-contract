// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

library ValidatorSigDecoder {
    /*
    validator signature format
    +----------------------------------------------------------+
    |                                                          |
    |             validator signature                          |
    |                                                          |
    +-------------------------------+--------------------------+
    |         signature type        |       signature data     |
    +-------------------------------+--------------------------+
    |                               |                          |
    |            1 byte             |          ......          |
    |                               |                          |
    +-------------------------------+--------------------------+

    

    A: signature type 0: eoa sig without validation data

    +------------------------------------------------------------------------+
    |                                                                        |
    |                             validator signature                        |
    |                                                                        |
    +--------------------------+----------------------------------------------+
    |       signature type     |                signature data                |
    +--------------------------+----------------------------------------------+
    |                          |                                              |
    |           0x00           |                    65 bytes                  |
    |                          |                                              |
    +--------------------------+----------------------------------------------+
    
    B: signature type 1: eoa sig with validation data

    +-------------------------------------------------------------------------------------+
    |                                                                                     |
    |                                        validator signature                          |
    |                                                                                     |
    +-------------------------------+--------------------------+---------------------------+
    |         signature type        |      validationData      |       signature data      |
    +-------------------------------+--------------------------+---------------------------+
    |                               |                          |                           |
    |            0x01               |     uint256 32 bytes     |           65 bytes        |
    |                               |                          |                           |
    +-------------------------------+--------------------------+---------------------------+

    
    C: signature type 2: passkey sig without validation data
    -----------------------------------------------------------------------------------------------------------------+
    |                                                                                                                |
    |                                     validator singature                                                        |
    |                                                                                                                |
    +-------------------+--------------------------------------------------------------------------------------------+
    |                   |                                                                                            |
    |   signature type  |                            signature data                                                  |
    |                   |                                                                                            |
    +----------------------------------------------------------------------------------------------------------------+
    |                   |                                                                                            |
    |                   |                                                                                            |
    |    0x02           |                        passkey dynamic signature                                           |
    |                   |                                                                                            |
    |                   |                                                                                            |
    +-------------------+--------------------------------------------------------------------------------------------+

     D: signature type 3: passkey sig without validation data
    ------------------------------------------------------------------------------------------------------------------------------------+
    |                                                                                                                                   |
    |                                                        validator singature                                                        |
    |                                                                                                                                   |
    +-----------------+--------------------+--------------------------------------------------------------------------------------------+
    |                 |                    |                                                                                            |
    |   sig type      |  validation data   |                            signature data                                                  |
    |                 |                    |                                                                                            |
    +-----------------------------------------------------------------------------------------------------------------------------------+
    |                 |                    |                                                                                            |
    |    0x03         |     uint256        |                         passkey dynamic signature                                          |
    |                 |     32 bytes       |                                                                                            |
    +-----------------+--------------------+--------------------------------------------------------------------------------------------+

     */

    function decodeValidatorSignature(
        bytes calldata validatorSignature
    )
        internal
        pure
        returns (
            uint8 signatureType,
            uint256 validationData,
            bytes calldata signature
        )
    {
        require(
            validatorSignature.length >= 1,
            "validator signature too short"
        );

        signatureType = uint8(bytes1(validatorSignature[0:1]));
        if (signatureType == 0x0) {
            require(
                validatorSignature.length == 66,
                "invalid validator signature length"
            );
            validationData = 0;
            signature = validatorSignature[1:66];
        } else if (signatureType == 0x1) {
            require(
                validatorSignature.length == 98,
                "invalid validator signature length"
            );
            validationData = uint256(bytes32(validatorSignature[1:33]));
            signature = validatorSignature[33:98];
        } else if (signatureType == 0x2) {
            require(
                validatorSignature.length >= 129,
                "invalid validator signature length"
            );
            validationData = 0;
            signature = validatorSignature[1:];
        } else if (signatureType == 0x3) {
            require(
                validatorSignature.length >= 161,
                "invalid validator signature length"
            );
            validationData = uint256(bytes32(validatorSignature[1:33]));
            signature = validatorSignature[33:];
        } else {
            revert("invalid validator signature type");
        }
    }
}
