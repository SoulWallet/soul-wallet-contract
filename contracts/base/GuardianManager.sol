// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./AccountManager.sol";
import "../libraries/SafeLock.sol";

abstract contract GuardianManager is AccountManager {

    bytes32 private constant GUARDIAN_TIMELOCK_TAG = keccak256("soulwallet.contracts.modules.GuardianManager.GUARDIAN_TIMELOCK_TAG");
    

    function _requireFromGuardian() internal view  {
        revert("not implemented");
    }

    function setGuardian(address guardian) public {
        _requireFromEntryPointOrOwner();
        //require(SafeLock._tryRequireSafeLock(GUARDIAN_TIMELOCK_TAG,keccak256(abi.encodePacked(guardian))));
    }

    function socialRecovery(
        address[] calldata _add,
        address[] calldata _delete
    ) public {
        _requireFromGuardian();
        resetOwner(_add, _delete);
    }
}
