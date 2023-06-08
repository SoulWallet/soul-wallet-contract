// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./GuardByteSlot.sol";

contract ExecutionManagerGuard is GuardByteSlot {
    bytes32 private constant _BYTE_MASK = 0xff00ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    modifier executionHook() {
        assembly {
            // load 32 byte value from slot _BIT_SLOT
            let data := sload(_BIT_SLOT)
            // load the second byte, BYTE = (x >> (248 - i * 8)) && 0xFF [x=data,i=1]
            let _byte := byte(1, data)
            // if allready set the bit(_byte == 1), revert
            if eq(_byte, 1) { revert(0, 0) }
            // if not set the bit(_byte == 0), set the bit=1 and store
            data := and(data, _BYTE_MASK)
            data := or(data, shl(240, 1))
            sstore(_BIT_SLOT, data)
        }
        _;
        assembly {
            let data := sload(_BIT_SLOT)
            let _byte := byte(1, data)
            // if not set the bit(_byte == 0), revert
            if eq(_byte, 0) { revert(0, 0) }
            // if allready set the bit(_byte == 1), set the bit=0 and store
            data := and(data, _BYTE_MASK)
            data := or(data, shl(240, 0))
            sstore(_BIT_SLOT, data)
        }
    }

    function _callFromExecutionManager() internal view returns (bool callFromExecutionManager) {
        /*  Equivalent code：
            if (msg.sender != address(this)) {
                return false;
            } else {
                return isInExecutionManager();
            }
        */
        assembly {
            if eq(caller(), address()) {
                let _byte := byte(1, sload(_BIT_SLOT))
                callFromExecutionManager := eq(_byte, 1)
            }
        }
    }
}
