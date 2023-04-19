// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../libraries/AccountStorage.sol";
import "../interfaces/ISafeLock.sol";

library SafeLock { 

    function _getSafeLockTime() private view returns (uint256) {
        return AccountStorage.layout().safeLockTime;
    }

    function _tryRequireSafeLock(bytes32 tag, bytes32 dataHash) internal returns (bool) {
        ISafeLock.SafeLockInfo memory lockInfo = AccountStorage.layout().safeLockStorage[tag];
        (lockInfo);
        AccountStorage.layout().safeLockStorage[tag] = ISafeLock.SafeLockInfo({
            dataHash: dataHash,
            unlockTime: block.timestamp + _getSafeLockTime()
        });
        return true;
    }

    function _tryCancelSafeLock(bytes32 tag) internal returns (bool) {
        AccountStorage.layout().safeLockStorage[tag] = ISafeLock.SafeLockInfo({
            dataHash: 0,
            unlockTime: 0
        });
        return true;
    }

    function _tryUnlockSafeLock(bytes32 tag, bytes32 dataHash) internal returns (bool) {
        ISafeLock.SafeLockInfo memory lockInfo = AccountStorage.layout().safeLockStorage[tag];
        require(lockInfo.dataHash == dataHash, "SafeLock: invalid data hash");
        require(lockInfo.unlockTime <= block.timestamp, "SafeLock: not unlock time");
        AccountStorage.layout().safeLockStorage[tag] = ISafeLock.SafeLockInfo({
            dataHash: 0,
            unlockTime: 0
        });
        return true;
    }
}
