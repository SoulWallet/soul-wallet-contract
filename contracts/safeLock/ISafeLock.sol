// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

interface ISafeLock {
    function getSafeLockPeriod() external view returns (uint64);

    function getSafeLockStatus(bytes32 _safeLockHash) external view returns (uint64);
}
