// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @dev Interface of the GuardianControl
 */
interface ILogicUpgradeControl {
    struct UpgradeLayout {
        uint32 upgradeDelay; // upgradeDelay
        uint64 activateTime; // activateTime
        address pendingImplementation; // pendingImplementation
        uint256[50] __gap;
    }

    /**
     * @dev Emitted before upgrade logic
     */
    event PreUpgrade(address newLogic, uint64 activateTime);

    /**
     * @dev Emitted when `implementation` is upgraded.
     */
    event Upgraded(address newImplementation);
}
