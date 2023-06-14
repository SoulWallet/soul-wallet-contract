// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

contract SoulWalletProxy {
    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1
     */
    bytes32 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Initializes the contract setting the implementation
     *
     * @param logic Address of the initial implementation.
     */
    constructor(address logic) {
        assembly ("memory-safe") {
            sstore(_IMPLEMENTATION_SLOT, logic)
        }
    }

    /**
     * @dev Fallback function
     */
    fallback() external payable {
        assembly {
            /* not memory-safe */
            let _singleton := and(sload(_IMPLEMENTATION_SLOT), 0xffffffffffffffffffffffffffffffffffffffff)
            calldatacopy(0, 0, calldatasize())
            let success := delegatecall(gas(), _singleton, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            if eq(success, 0) { revert(0, returndatasize()) }
            return(0, returndatasize())
        }
    }
}
