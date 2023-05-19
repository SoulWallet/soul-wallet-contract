// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;


struct GuardianInfo {
    mapping(address => address) guardians;
    uint256 threshold;
    bytes32 guardianHash;
}

struct PendingGuardianEntry {
    uint256 pendingUntil;
    uint256 threshold;
    bytes32 guardianHash;
    address[] guardians;
}

struct RecoveryEntry {
    address[] newOwners;
    uint256 executeAfter;
    uint256 nonce;
}

// 1. changing guardians while already in recovery?
// not allowed. recovery will block wallet
// 2. recovery while already in chainging guardian?
// will cancel the changing guardian

interface ISocialRecoveryModule {
    event AnonymousGuardianRevealed(address indexed wallet, address[] indexed guardians, bytes32 guardianHash);
    event ApproveRecovery(address indexed wallet, address indexed guardian, bytes32 indexed recoveryHash);
    event  PendingRecovery(address indexed _wallet, address[] indexed _newOwners, uint256 _nonce, uint256 executeAfter);
    event  SocialRecovery(address indexed _wallet, address[] indexed _newOwners);
    event  SocialRecoveryCanceled(address indexed _wallet, uint256 _nonce);
    // change guardians --> wait 2 day --> guardian changed
    function updateGuardians(
        address[] calldata _guardians,
        uint256 _threshold,
        bytes32 _guardianHash
    ) external;

    function cancelSetGuardians(address _wallet) external; // owner or guardian

    function getGuardians(address _wallet) external returns (address[] memory);

    // init recovery --> over half guardian confirm recovery --> wait 2 day --> execute recovery
    //                |
    //                --> all guardian confim recovery --> execute recovery
    function batchApproveRecovery(
        address _wallet,
        address[] calldata _newOwners,
        uint256 signatureCount,
        bytes memory signatures
    ) external;

    function approveRecovery(
        address _wallet,
        address[] calldata _newOwners
    ) external;

    function executeRecovery(address _wallet) external;

    function cancelRecovery(address _wallet) external;

}
