// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title KeyStoreSlotLib
 * @notice A library to compute a keystore slot based on input parameters
 */
library KeyStoreSlotLib {
    /**
     * @notice Calculates a slot using the initial key hash, initial guardian hash, and guardian safe period
     * @param initialKeyHash The initial key hash used for calculating the slot
     * @param initialGuardianHash The initial guardian hash used for calculating the slot
     * @param guardianSafePeriod The guardian safe period used for calculating the slot
     * @return slot The resulting keystore slot derived from the input parameters
     */
    function getSlot(bytes32 initialKeyHash, bytes32 initialGuardianHash, uint256 guardianSafePeriod)
        internal
        pure
        returns (bytes32 slot)
    {
        return keccak256(abi.encode(initialKeyHash, initialGuardianHash, guardianSafePeriod));
    }
}
