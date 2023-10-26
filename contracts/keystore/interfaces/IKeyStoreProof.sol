// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title Key Store Proof Interface
 * @dev This interface provides methods to retrieve the keystore signing key hash and raw owners based on a slot.
 */
interface IKeyStoreProof {
    /**
     * @dev Returns the signing key hash associated with a given L1 slot.
     * @param l1Slot The L1 slot
     * @return signingKeyHash The hash of the signing key associated with the L1 slot
     */
    function keystoreBySlot(bytes32 l1Slot) external view returns (bytes32 signingKeyHash);

    /**
     * @dev Returns the raw owners associated with a given L1 slot.
     * @param l1Slot The L1 slot
     * @return owners The raw owner data associated with the L1 slot
     */
    function rawOwnersBySlot(bytes32 l1Slot) external view returns (bytes memory owners);
}
