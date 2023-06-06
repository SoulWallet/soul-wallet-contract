// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./GuardByteSlot.sol";

contract ModuleGuard is GuardByteSlot {
    bytes32 private constant _BYTE_MASK = 0x00ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    modifier moduleHook() {
        assembly {
            // load 32 byte value from slot _BIT_SLOT
            let data := sload(_BIT_SLOT)
            // load the first byte, BYTE = (x >> (248 - i * 8)) && 0xFF [x=data,i=0]
            let _byte := byte(0, data)
            // if allready set the bit(_byte == 1), revert
            if eq(_byte, 1) { revert(0, 0) }
            // if not set the bit(_byte == 0), set the bit=1 and store
            data := and(data, _BYTE_MASK)
            data := or(data, shl(248, 1))
            sstore(_BIT_SLOT, data)
        }
        _;
        assembly {
            let data := sload(_BIT_SLOT)
            let _byte := byte(0, data)
            // if not set the bit(_byte == 0), revert
            if eq(_byte, 0) { revert(0, 0) }
            // if allready set the bit(_byte == 1), set the bit=0 and store
            data := and(data, _BYTE_MASK)
            data := or(data, shl(248, 0))
            sstore(_BIT_SLOT, data)
        }
    }

    function _isInModule() internal view returns (bool _inModule) {
        require(msg.sender == address(this), "require from Module");
        assembly {
            let _byte := byte(0, sload(_BIT_SLOT))
            _inModule := eq(_byte, 1)
        }
    }

    modifier onlyModule() {
        require(_isInModule(), "require from Module");
        _;
    }
}
