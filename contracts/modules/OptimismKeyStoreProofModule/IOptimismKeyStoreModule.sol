// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

interface IOptimismKeyStoreModule {
    event KeyStoreSyncd(address indexed _wallet, address indexed _newOwners);

    function syncL1Keystore(address wallet) external;
}
