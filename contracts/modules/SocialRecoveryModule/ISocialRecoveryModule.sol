// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

struct RecoveryRecord {
    address wallet;
    address[] newOwners;
    uint256 nonce;
}

// 1. changing guardians while already in recovery? 
// not allowed. recovery will block wallet
// 2. recovery while already in chainging guardian?
// will cancel the changing guardian

interface ISocialRecoveryModule {

    // change guardians --> wait 2 day --> guardian changed
    function setGuardians(address[] calldata guardians) external;
    function setAnomousGuardians(uint256 guardianHash) external;
    function cancelSetGuardians(address wallet) external; // owner or guardian
    function getGuardians(address wallet) external returns (address[] memory);

    // init recovery --> over half guardian confirm recovery --> wait 2 day --> execute recovery
    //                |
    //                --> all guardian confim recovery --> execute recovery
    function batchConfirmRecovery(RecoveryRecord calldata recoveryRecord, bytes[] calldata signatures) external;
    function confirmRecovery(RecoveryRecord calldata recoveryRecord) external;
    function executeRecovery(uint256 recoveryHash) external;
    function cancelRecovery(uint256 recoveryHash) external;

    // function lockWallet(address wallet) external;
}
