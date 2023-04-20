// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

interface ISafeLock {

    struct SafeLockLayout {
        uint64 safeLockPeriod;
        mapping(bytes32 => uint64) safeLockStatus;
    }

    function getSafeLockPeriod() external view returns (uint64);

    function getSafeLockStatus(bytes32 _safeLockHash) external view returns (uint64);
}
