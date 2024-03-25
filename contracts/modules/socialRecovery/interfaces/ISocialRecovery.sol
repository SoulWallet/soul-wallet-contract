// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

interface ISocialRecovery {
    struct SocialRecoveryInfo {
        bytes32 guardianHash;
        uint256 nonce;
        // transaction id to transaction valid time
        mapping(bytes32 id => uint256) txValidAt;
        uint256 delayPeriod;
    }

    function walletNonce(address wallet) external view returns (uint256 _nonce);

    /**
     * @notice  .
     * @dev     .
     * @param   wallet to recovery
     * @param   newRawOwners abi.encode(address[] owners)
     * @param   rawGuardian abi.encode(GuardianData)
     *  struct GuardianData {
     *     address[] guardians;
     *     uint256 threshold;
     *     uint256 salt;
     * }
     * @param   guardianSignature  .
     * @return  recoveryId  .
     */
    function scheduleReocvery(
        address wallet,
        bytes calldata newRawOwners,
        bytes calldata rawGuardian,
        bytes calldata guardianSignature
    ) external returns (bytes32 recoveryId);

    function executeReocvery(
        address wallet,
        bytes calldata newRawOwners,
        bytes calldata rawGuardian,
        bytes calldata guardianSignature
    ) external;

    function setGuardian(bytes32 newGuardianHash) external;
    function setDelayPeriod(uint256 newDelay) external;
    function cancelReocvery(bytes32 recoveryId) external;

    enum OperationState {
        Unset,
        Waiting,
        Ready,
        Done
    }

    struct GuardianData {
        address[] guardians;
        uint256 threshold;
        uint256 salt;
    }
}
