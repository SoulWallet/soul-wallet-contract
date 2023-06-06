// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

contract GuardByteSlot {
    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1
     * Current use this hot storage slot for lower gas
     */
    bytes32 internal constant _BIT_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
}
