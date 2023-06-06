// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./GuardByteSlot.sol";

contract ModuleGuard is GuardByteSlot {
    bytes32 private constant _BYTE_MASK = 0x00ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    modifier moduleHook() {
        assembly {
            let data := sload(_BIT_SLOT)
            let _byte := byte(0, data)
            if eq(_byte, 1) { revert(0, 0) }
            data := and(data, _BYTE_MASK)
            data := or(data, shl(248, 1))
            sstore(_BIT_SLOT, data)
        }
        _;
        assembly {
            let data := sload(_BIT_SLOT)
            let _byte := byte(0, data)
            if eq(_byte, 0) { revert(0, 0) }
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
