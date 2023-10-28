// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title SoulWalletProxy
 * @notice A proxy contract that forwards calls to an implementation contract
 * @dev This proxy uses the EIP-1967 standard for storage slots
 */
contract SoulWalletProxy {
    /**
     * @notice Storage slot with the address of the current implementation
     * @dev This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1
     */
    bytes32 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @notice Initializes the proxy with the address of the initial implementation contract
     * @param logic Address of the initial implementation
     */
    constructor(address logic) {
        assembly ("memory-safe") {
            sstore(_IMPLEMENTATION_SLOT, logic)
        }
    }

    /**
     * @notice Fallback function which forwards all calls to the implementation contract
     * @dev Uses delegatecall to ensure the context remains within the proxy
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
