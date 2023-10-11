// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "../libraries/Errors.sol";

library SignatureDecoder {
    /*
    signature format

    +-----------------------------------------------------------------------------------------------------+
    |                                           |                                                         |
    |                                           |                   validator signature                   |
    |                                           |                                                         |
    +---------------+---------------------------+--------------------------+-----------------------------+
    |     data type | data type dynamic data    |     signature type       |       signature data        |
    +---------------+---------------------------+--------------------------+-----------------------------+
    |               |                           |                          |                             |
    |    1 byte     |      ..........           |        1 byte            |          ......             |
    |               |                           |                          |                             |
    +-----------------------------------------------------------------------------------------------------+


    A: data type 0: no plugin data
    +-----------------------------------------------------------------------------------------------------+
    |                                           |                                                         |
    |                                           |                   validator signature                   |
    |                                           |                                                         |
    +---------------+---------------------------+--------------------------+-----------------------------+
    |     data type | data type dynamic data    |     signature type       |       signature data        |
    +---------------+---------------------------+--------------------------+-----------------------------+
    |               |                           |                          |                             |
    |     0x00      |      empty bytes          |        1 byte            |          ......             |
    |               |                           |                          |                             |
    +-----------------------------------------------------------------------------------------------------+




     B: data type 1: plugin data

    +-----------------------------------------------------------------------------------------------------+
    |                                           |                                                         |
    |                                           |                   validator signature                   |
    |                                           |                                                         |
    +---------------+---------------------------+--------------------------+-----------------------------+
    |     data type | data type dynamic data    |     signature type       |       signature data        |
    +---------------+---------------------------+--------------------------+-----------------------------+
    |               |                           |                          |                             |
    |     0x01      |      .............        |        1 byte            |          ......             |
    |               |                           |                          |                             |
    +-----------------------------------------------------------------------------------------------------+



    +-------------------------+-------------------------------------+
    |                                                               |
    |                  data type dynamic data                       |
    |                                                               |
    +-------------------------+-------------------------------------+
    | dynamic data length     | multi-guardHookInputData            |
    +-------------------------+-------------------------------------+
    | uint256 32 bytes        | dynamic data without length header  |
    +-------------------------+-------------------------------------+


    +--------------------------------------------------------------------------------+
    |                            multi-guardHookInputData                            |
    +--------------------------------------------------------------------------------+
    |   guardHookInputData  |  guardHookInputData   |   ...  |  guardHookInputData   |
    +-----------------------+-----------------------+--------+-----------------------+
    |     dynamic data      |     dynamic data      |   ...  |     dynamic data      |
    +--------------------------------------------------------------------------------+

    +----------------------------------------------------------------------+
    |                                guardHookInputData                    |
    +----------------------------------------------------------------------+
    |   guardHook address  |   input data length   |      input data       |
    +----------------------+-----------------------+-----------------------+
    |        20bytes       |     6bytes(uint48)    |         bytes         |
    +----------------------------------------------------------------------+

    Note: The order of guardHookInputData must be the same as the order in PluginManager.guardHook()!

     */

    function decodeSignature(bytes calldata userOpsignature)
        internal
        pure
        returns (bytes calldata guardHookInputData, bytes calldata validatorSignature)
    {
        // Ensure that userOpsignature has at least 1 byte (for dataType)
        require(userOpsignature.length >= 1, "Signature too short");

        uint8 dataType = uint8(bytes1(userOpsignature[0:1]));

        if (dataType == 0x0) {
            // For dataType 0x0, the minimum length should be 2 bytes (1 for dataType and 1 for signature type)
            require(userOpsignature.length >= 2, "Signature too short for dataType 0x0");
            // empty guardHookInputData
            guardHookInputData = userOpsignature[0:0];
            validatorSignature = userOpsignature[1:];
        } else if (dataType == 0x01) {
            // For dataType 0x01, the minimum length should be 65 bytes (1 for dataType, 32 for dynamicDataLength, then some bytes for the multi-guardHookInputData and signature data)
            require(userOpsignature.length >= 33, "Signature too short for dataType 0x01");

            uint256 dynamicDataLength = uint256(bytes32(userOpsignature[1:33]));
            // Ensure the given dynamicDataLength doesn't exceed available bytes
            require(33 + dynamicDataLength <= userOpsignature.length, "Invalid dynamicDataLength");

            guardHookInputData = userOpsignature[33:33 + dynamicDataLength];
            validatorSignature = userOpsignature[33 + dynamicDataLength:];
        } else {
            revert("Unsupported data type");
        }
    }
}
