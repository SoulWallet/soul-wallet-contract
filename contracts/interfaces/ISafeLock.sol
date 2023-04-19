// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;


interface ISafeLock {
    struct SafeLockInfo {
        bytes32 dataHash;
        uint256 unlockTime;
    }
}
