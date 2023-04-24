// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./ISocialRecoveryModule.sol";

struct GuardianInfo {
    address[] guardians;
    uint256 guardianHash;
    uint256 salt;
}

struct PendingGuardianEntry {
    uint256 pendingUntil;
    GuardianInfo guardianInfo;
}

struct RecoveryEntry {
    RecoveryRecord record;
    uint256 numConfirmed;
    uint256 executeTimestamp;
}

abstract contract SocialRecoveryModule is ISocialRecoveryModule {
    mapping (address => uint256) recoveryNonce;

    mapping (address => GuardianInfo) internal walletGuardian;
    mapping (address => PendingGuardianEntry) internal walletPendingGuardian;
    
    mapping (uint256 => mapping (address => bool)) confirmedRecords;
    mapping (address => RecoveryEntry) recoveryEntries;

    function _checkLatestGuardian(address wallet) private {
        if (walletPendingGuardian[wallet].pendingUntil > 0 &&
            walletPendingGuardian[wallet].pendingUntil > block.timestamp) {
            walletGuardian[wallet] = walletPendingGuardian[wallet].guardianInfo;
            delete walletPendingGuardian[wallet];
        }        
    }
    modifier checkLatestGuardian(address wallet) {
        _checkLatestGuardian(wallet);
        _;
    }

    function guardianInfo(address wallet) public view returns (GuardianInfo memory) {
        if (walletPendingGuardian[wallet].pendingUntil > 0 &&
            walletPendingGuardian[wallet].pendingUntil > block.timestamp) {
            return walletPendingGuardian[wallet].guardianInfo;
        }
        return walletGuardian[wallet];
    }

    function guardiansCount(address wallet) public view returns (uint256) {
        return guardianInfo(wallet).guardians.length;
    }

    function getGuardians(address wallet) public view returns (address[] memory) {
        return guardianInfo(wallet).guardians;
    }

    function setGuardians(address[] calldata guardians) checkLatestGuardian(msg.sender) external {
        // TODO: require not in recovery;
        address wallet = msg.sender;
        PendingGuardianEntry memory pendingEntry;
        pendingEntry.pendingUntil = block.timestamp + 2 days;
        pendingEntry.guardianInfo.guardians = guardians;
        walletPendingGuardian[wallet] = pendingEntry;
    }

    function setAnomousGuardians(uint256 guardianHash) checkLatestGuardian(msg.sender) external {
        // TODO: require not in recovery;
        address wallet = msg.sender;
        PendingGuardianEntry memory pendingEntry;
        pendingEntry.pendingUntil = block.timestamp + 2 days;
        pendingEntry.guardianInfo.guardianHash = guardianHash;
        walletPendingGuardian[wallet] = pendingEntry;
    }

    // owner or guardian
    function cancelSetGuardians(address wallet) checkLatestGuardian(msg.sender) external {
        if (wallet != msg.sender) {
            // TODO: require msg.sender is guardian of wallet;
        }
        delete walletPendingGuardian[wallet];
    }

    function revealAnomousGuardians(address wallet, address[] calldata guardians, uint256 salt) checkLatestGuardian(msg.sender) public {
        // 1. check hash
        // 2. update guardian list in storage
    }

    function batchConfirmRecovery(RecoveryRecord calldata recoveryRecord, bytes[] calldata signatures) external checkLatestGuardian(msg.sender) {
        // 1. clear pending guardian setting
        // 2. get recoverHash = hash(recoveryRecord) with EIP712
        // 3. verify signatures, verify is guardian
        // 4. update recoveryEntries
        // 6. if (numConfirmed == numGuardian) execute Recovery
        // 5. if (numConfirmed > threshold) update RecoveryEntry.executeUntil
    }

    function confirmRecovery(RecoveryRecord calldata recoveryRecord) external checkLatestGuardian(msg.sender) {
    }

    function executeRecovery(uint256 recoveryHash) external {
        // 1. check RecoveryEntry.executeUntil > block.timestamp
        // 2. reset wallet owners
        // 3. delete RecoveryEntry
    }

    // TODO: collect cancel signature
    function cancelRecovery(uint256 recoveryHash) external {

    }
}