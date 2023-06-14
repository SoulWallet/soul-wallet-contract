// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../libraries/Errors.sol";

library SignatureDecoder {
    /*
    
    A:
        # `signType` 0x00:
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

        # `signType` 0x01:
        - EOA signature with validationData ( validAfter and validUntil ) and Plugin guardHook input data
        +--------------------------------------------------------------------------------------+  
        |                                   dynamic data                                       |  
        +--------------------------------------------------------------------------------------+  
        |     validationData    |        signature        |    multi-guardHookInputData       |
        +-----------------------+--------------------------------------------------------------+  
        |    uint256 32 bytes   |   65 length signature   | dynamic data without length header |
        +--------------------------------------------------------------------------------------+

        +--------------------------------------------------------------------------------+  
        |                            multi-guardHookInputData                            |  
        +--------------------------------------------------------------------------------+  
        |   guardHookInputData  |  guardHookInputData   |   ...  |  guardHookInputData   |
        +-----------------------+--------------------------------------------------------+  
        |     dynamic data      |     dynamic data      |   ...  |     dynamic data      |
        +--------------------------------------------------------------------------------+

        +----------------------------------------------------------------------+  
        |                                guardHookInputData                    |  
        +----------------------------------------------------------------------+  
        |   guardHook address  |   input data length   |      input data       |
        +----------------------+-----------------------------------------------+  
        |        20bytes       |     6bytes(uint48)    |         bytes         |
        +----------------------------------------------------------------------+
        Note: The order of guardHookInputData must be the same as the order in PluginManager.guardHook()!


        # `signType` 0x02: (Not implemented yet)
        - EIP-1271 signature without validationData
        +-----------------------------------------------------------------+
        |                        dynamic data                             |
        +-----------------------------------------------------------------+
        |         signer       |  signature (dynamic with length header)  |
        +----------------------+------------------------------------------+
        |    address 20 byte   |       dynamic with length header         |
        +-----------------------------------------------------------------+

     */

    function decodeSignature(bytes calldata userOpsignature)
        internal
        pure
        returns (uint8 signType, bytes calldata signature, uint256 validationData, bytes calldata guardHookInputData)
    {
        if (userOpsignature.length == 65) {
            signature = userOpsignature;
            guardHookInputData = userOpsignature[0:0];
        } else {
            signType = uint8(userOpsignature[0]);
            if (signType == 0x1) {
                validationData = abi.decode(userOpsignature[1:33], (uint256));
                signature = userOpsignature[33:98];
                guardHookInputData = userOpsignature[98:];
            } else {
                revert Errors.UNSUPPORTED_SIGNTYPE();
            }
        }
    }
}
