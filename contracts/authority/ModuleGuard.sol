// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

contract ModuleGuard {
    bytes32 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 private constant _BYTE_MASK = 0x00ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    modifier moduleHook() {
        assembly {
            let data := sload(_IMPLEMENTATION_SLOT)
            let _byte := byte(0, data)
            if eq(_byte, 1) { revert(0, 0) }
            data := and(data, _BYTE_MASK)
            data := or(data, shl(248, 1))
            sstore(_IMPLEMENTATION_SLOT, data)
        }
        _;
        assembly {
            let data := sload(_IMPLEMENTATION_SLOT)
            let _byte := byte(0, data)
            if eq(_byte, 0) { revert(0, 0) }
            data := and(data, _BYTE_MASK)
            data := or(data, shl(248, 0))
            sstore(_IMPLEMENTATION_SLOT, data)
        }
    }

    function _isInModule() internal view returns (bool _inModule) {
        assembly {
            let _byte := byte(0, sload(_IMPLEMENTATION_SLOT))
            _inModule := eq(_byte, 1)
        }
    }

    modifier onlyModule() {
        require(_isInModule(), "require from Module");
        _;
    }
}
