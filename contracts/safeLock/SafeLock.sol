// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./ISafeLock.sol";

abstract contract SafeLock is ISafeLock {
    bytes32 private immutable _SAFELOCK_SLOT;
    uint64 private immutable _SAFELOCK_PERIOD;

    constructor(string memory safeLockSlotName, uint64 safeLockPeriod) {
        _SAFELOCK_SLOT = keccak256(abi.encodePacked(safeLockSlotName));
        require(safeLockPeriod > 0, "SafeLock: safeLockPeriod must be greater than 0");
        _SAFELOCK_PERIOD = safeLockPeriod;
    }

    function _safeLockStatus() internal view returns (mapping(bytes32 => uint64) storage safeLockStatus) {
        bytes32 slot = _SAFELOCK_SLOT;
        assembly {
            safeLockStatus.slot := slot
        }
    }

    function _now() private view returns (uint64) {
        return uint64(block.timestamp);
    }

    function getSafeLockPeriod() external view returns (uint64) {
        return _SAFELOCK_PERIOD;
    }

    function getSafeLockStatus(bytes32 _safeLockHash) external view returns (uint64 unLockTime) {
        unLockTime = _safeLockStatus()[_safeLockHash];
    }

    function _tryLock(bytes32 _safeLockHash) internal returns (bool) {
        mapping(bytes32 => uint64) storage safeLockStatus = _safeLockStatus();
        if (safeLockStatus[_safeLockHash] != 0) {
            return false;
        }
        safeLockStatus[_safeLockHash] = _now() + _SAFELOCK_PERIOD;
        return true;
    }

    function _lock(bytes32 _safeLockHash) internal {
        require(_tryLock(_safeLockHash), "SafeLock: already locked");
    }

    function _cancelLock(bytes32 _safeLockHash) internal {
        _safeLockStatus()[_safeLockHash] = 0;
    }

    function _tryUnlock(bytes32 _safeLockHash) internal returns (bool) {
        mapping(bytes32 => uint64) storage safeLockStatus = _safeLockStatus();
        uint64 unlockTime = safeLockStatus[_safeLockHash];
        if (unlockTime == 0 || unlockTime > _now()) {
            return false;
        }
        safeLockStatus[_safeLockHash] = 0;
        return true;
    }

    function _unlock(bytes32 _safeLockHash) internal {
        require(_tryUnlock(_safeLockHash), "SafeLock: not unlock time");
    }
}
