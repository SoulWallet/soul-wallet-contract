// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

library KeyStoreSlotLib {
    function getSlot(bytes32 initialKeyHash, bytes32 initialGuardianHash, uint256 guardianSafePeriod)
        internal
        pure
        returns (bytes32 slot)
    {
        return keccak256(abi.encode(initialKeyHash, initialGuardianHash, guardianSafePeriod));
    }
}
