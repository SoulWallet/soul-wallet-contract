// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

contract GuardByteSlot {
    /**
     * @dev If only consider gas efficiency, we should choose to use `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc` (the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1)
     *      But we need to consider the security of the system, so we choose to use a separate cold slot.
     */
    bytes32 internal constant _BIT_SLOT = keccak256("soulwallet.temporary.bit");
}
