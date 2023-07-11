// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

library KeyStoreSlotLib {
    function getSlot(bytes32 initialKey, bytes32 initialGuardianHash, uint64 guardianSafePeriod)
        internal
        pure
        returns (bytes32 slot)
    {
        return keccak256(abi.encode(initialKey, initialGuardianHash, guardianSafePeriod));
    }
}
