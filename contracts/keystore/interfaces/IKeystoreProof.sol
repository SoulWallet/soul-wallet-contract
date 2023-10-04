// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

interface IKeyStoreProof {
    function keystoreBySlot(bytes32 l1Slot) external view returns (bytes32 signingKey);
    function rawOwnersBySlot(bytes32 l1Slot) external view returns (bytes memory owners);
}
