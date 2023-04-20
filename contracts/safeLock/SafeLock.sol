// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./ISafeLock.sol";

abstract contract SafeLock is ISafeLock {

    bytes32 private immutable safeLockSlot;

    constructor(string memory safeLockSlotName, uint64 safeLockPeriod) {
        safeLockSlot = keccak256(abi.encodePacked(safeLockSlotName));
        require(safeLockPeriod > 0, "SafeLock: safeLockPeriod must be greater than 0");
        safeLockLayout().safeLockPeriod = safeLockPeriod;
    }

    function safeLockLayout() internal view returns (SafeLockLayout storage l) {
        bytes32 slot = safeLockSlot;
        assembly {
            l.slot := slot
        }
    }

    function _now() private view returns (uint64) {
        return uint64(block.timestamp);
    }

    function getSafeLockPeriod() external view returns (uint64){
        return safeLockLayout().safeLockPeriod;
    }

    function getSafeLockStatus(bytes32 _safeLockHash) external view returns (uint64 unLockTime){
          unLockTime = safeLockLayout().safeLockStatus[_safeLockHash];
    }

    function tryLock(bytes32 _safeLockHash) internal returns (bool) {
        SafeLockLayout storage layout = safeLockLayout();
        mapping(bytes32 => uint64) storage safeLockStatus = layout.safeLockStatus;
        if (safeLockStatus[_safeLockHash] != 0) {
            return false;
        }
        safeLockStatus[_safeLockHash] = _now() + layout.safeLockPeriod;
        return true;
    }

    function lock(bytes32 _safeLockHash) internal{
        require(tryLock(_safeLockHash), "SafeLock: already locked");
    }

    function cancelLock(bytes32 _safeLockHash) internal{
        SafeLockLayout storage layout = safeLockLayout();
        mapping(bytes32 => uint64) storage safeLockStatus = layout.safeLockStatus;
        safeLockStatus[_safeLockHash] = 0;
    }

    function tryUnlock(bytes32 _safeLockHash) internal returns (bool) {
        SafeLockLayout storage layout = safeLockLayout();
        mapping(bytes32 => uint64) storage safeLockStatus = layout.safeLockStatus;
        uint64 unlockTime = safeLockStatus[_safeLockHash];
        if (unlockTime == 0 || unlockTime > _now()) {
            return false;
        }
        safeLockStatus[_safeLockHash] = 0;
        return true;
    }

    function unlock(bytes32 _safeLockHash) internal{
        require(tryUnlock(_safeLockHash), "SafeLock: not unlock time");
    }


}