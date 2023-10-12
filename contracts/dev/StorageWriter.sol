// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.20;

contract StorageWriter {
    // Event to log the storage write operation
    event StorageUpdated(bytes32 indexed slot, bytes32 value);

    /**
     * @dev Writes a bytes32 value to a specific storage slot using inline assembly.
     * @param slot The storage slot to write to.
     * @param key The bytes32 value to write.
     */
    function writeToSlot(bytes32 slot, bytes32 key) external {
        assembly {
            sstore(slot, key)
        }
        emit StorageUpdated(slot, key);
    }
}
