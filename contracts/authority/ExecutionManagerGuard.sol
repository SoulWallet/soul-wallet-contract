// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

contract ExecutionManagerGuard {
    bytes32 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 private constant _BYTE_MASK = 0xff00ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    modifier executionHook() {
        assembly {
            let data := sload(_IMPLEMENTATION_SLOT)
            let _byte := byte(1, data)
            if eq(_byte, 1) { revert(0, 0) }
            data := and(data, _BYTE_MASK)
            data := or(data, shl(240, 1))
            sstore(_IMPLEMENTATION_SLOT, data)
        }
        _;
        assembly {
            let data := sload(_IMPLEMENTATION_SLOT)
            let _byte := byte(1, data)
            if eq(_byte, 0) { revert(0, 0) }
            data := and(data, _BYTE_MASK)
            data := or(data, shl(240, 0))
            sstore(_IMPLEMENTATION_SLOT, data)
        }
    }

    function _isExecutionManager() internal view returns (bool _inExecutionManager) {
        assembly {
            let _byte := byte(1, sload(_IMPLEMENTATION_SLOT))
            _inExecutionManager := eq(_byte, 1)
        }
    }

    modifier onlyExecutionManager() {
        require(_isExecutionManager(), "require from ExecutionManager");
        _;
    }
}
