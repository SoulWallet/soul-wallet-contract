// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./GuardByteSlot.sol";

contract ExecutionManagerGuard is GuardByteSlot {
    bytes32 private constant _BYTE_MASK = 0xff00ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    modifier executionHook() {
        assembly {
            let data := sload(_BIT_SLOT)
            let _byte := byte(1, data)
            if eq(_byte, 1) { revert(0, 0) }
            data := and(data, _BYTE_MASK)
            data := or(data, shl(240, 1))
            sstore(_BIT_SLOT, data)
        }
        _;
        assembly {
            let data := sload(_BIT_SLOT)
            let _byte := byte(1, data)
            if eq(_byte, 0) { revert(0, 0) }
            data := and(data, _BYTE_MASK)
            data := or(data, shl(240, 0))
            sstore(_BIT_SLOT, data)
        }
    }

    function _isExecutionManager() internal view returns (bool _inExecutionManager) {
        require(msg.sender == address(this), "require from ExecutionManager");
        assembly {
            let _byte := byte(1, sload(_BIT_SLOT))
            _inExecutionManager := eq(_byte, 1)
        }
    }

    modifier onlyExecutionManager() {
        require(_isExecutionManager(), "require from ExecutionManager");
        _;
    }
}
