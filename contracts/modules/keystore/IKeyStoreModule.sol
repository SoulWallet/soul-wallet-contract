// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title IKeyStoreModule
 * @notice Interface for the KeyStoreModule, responsible for managing and syncing keystores
 */
interface IKeyStoreModule {
    /**
     * @notice Emitted when the keystore for a specific wallet has been synchronized
     * @param _wallet The address of the wallet for which the keystore has been synced
     * @param _newOwners The new owners of the keystore represented as a bytes32 value
     */
    event KeyStoreSyncd(address indexed _wallet, bytes32 indexed _newOwners);
    /**
     * @notice Emitted when a keystore is initialized
     * @param _wallet The address of the wallet for which the keystore has been initialized
     * @param _initialKey The initial key set for the keystore represented as a bytes32 value
     * @param initialGuardianHash The initial hash value for the guardians
     * @param guardianSafePeriod The safe period for guardians
     */
    event KeyStoreInited(
        address indexed _wallet, bytes32 _initialKey, bytes32 initialGuardianHash, uint64 guardianSafePeriod
    );
    /**
     * @dev Synchronizes the keystore for a specific wallet
     * @param wallet The address of the wallet to be synchronized
     */

    function syncL1Keystore(address wallet) external;
}
