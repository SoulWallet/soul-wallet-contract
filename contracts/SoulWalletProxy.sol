// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

contract SoulWalletProxy {
    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;


    /**
     * @dev Initializes the contract setting the implementation,
     * `data` turn some parameters into immediate operand to reduce the gas consumption.
     * 
     * @param logic Address of the initial implementation.
     * @param data all data to be passed to the implementation
     */
    constructor(address logic, bytes memory data) {
        assembly {
            sstore(_IMPLEMENTATION_SLOT, logic)
            let result := delegatecall(gas(), logic, add(data, 0x20), mload(data), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
    
    /**
     * @dev Fallback function
     */
    fallback() external payable {
        assembly {
            let _singleton := and(sload(_IMPLEMENTATION_SLOT), 0xffffffffffffffffffffffffffffffffffffffff)
            calldatacopy(0, 0, calldatasize())
            let success := delegatecall(gas(), _singleton, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            if eq(success, 0) {
                revert(0, returndatasize())
            }
            return(0, returndatasize())
        }
    }
}