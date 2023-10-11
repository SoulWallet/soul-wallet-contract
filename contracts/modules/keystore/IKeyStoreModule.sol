// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

interface IKeyStoreModule {
    event KeyStoreSyncd(address indexed _wallet, bytes32 indexed _newOwners);
    event KeyStoreInited(
        address indexed _wallet, bytes32 _initialKey, bytes32 initialGuardianHash, uint64 guardianSafePeriod
    );

    function syncL1Keystore(address wallet) external;
}
