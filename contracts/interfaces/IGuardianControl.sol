// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @dev Interface of the GuardianControl
 */
interface IGuardianControl {
    struct GuardianLayout {
        // guardian now
        address guardian;
        // guardian next
        address pendingGuardian;
        // `guardian next` effective time
        uint64 activateTime;
        // guardian delay
        uint32 guardianDelay;
        uint256[50] __gap;
    }

    /**
     * @dev Emitted when `guardian` is set/updated.
     */
    event GuardianSet(address newGuardian, address oldGuardian);

    
}
