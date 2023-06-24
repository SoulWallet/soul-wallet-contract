// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../interfaces/IUpgradable.sol";
import "../libraries/Errors.sol";

abstract contract UpgradeManager is IUpgradable {
    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1
     */
    bytes32 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function _upgradeTo(address newImplementation) internal {
        bool isContract;
        assembly ("memory-safe") {
            isContract := gt(extcodesize(newImplementation), 0)
        }
        if (!isContract) {
            revert Errors.INVALID_LOGIC_ADDRESS();
        }
        address oldImplementation;
        assembly ("memory-safe") {
            oldImplementation := and(sload(_IMPLEMENTATION_SLOT), 0xffffffffffffffffffffffffffffffffffffffff)
        }
        if (oldImplementation == newImplementation) {
            revert Errors.SAME_LOGIC_ADDRESS();
        }
        assembly ("memory-safe") {
            sstore(_IMPLEMENTATION_SLOT, newImplementation)
        }

        // delegatecall to new implementation
        (bool success,) =
            newImplementation.delegatecall(abi.encodeWithSelector(IUpgradable.upgradeFrom.selector, oldImplementation));
        if (!success) {
            revert Errors.UPGRADE_FAILED();
        }
        emit Upgraded(oldImplementation, newImplementation);
    }
}
