// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

interface IKeyStoreModule {
    event KeyStoreSyncd(address indexed _wallet, address indexed _newOwners);
    event KeyStoreInited(
        address indexed _wallet, bytes32 _initialKey, bytes32 initialGuardianHash, uint64 guardianSafePeriod
    );

    function syncL1Keystore(address wallet) external;
}
