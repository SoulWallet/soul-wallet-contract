// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IOwnable} from "./IOwnable.sol";

interface IOwnerManager is IOwnable {
    /**
     * @notice Emitted when an owner is added
     * @param owner owner
     */
    event OwnerAdded(bytes32 indexed owner);

    /**
     * @notice Emitted when an owner is removed
     * @param owner owner
     */
    event OwnerRemoved(bytes32 indexed owner);

    /**
     * @notice Emitted when all owners are removed
     */
    event OwnerCleared();

    /**
     * @notice Adds a new owner to the system
     * @param owner The bytes32 ID of the owner to be added
     */
    function addOwner(bytes32 owner) external;

    /**
     * @notice Removes an existing owner from the system
     * @param owner The bytes32 ID of the owner to be removed
     */
    function removeOwner(bytes32 owner) external;

    /**
     * @notice Resets the entire owner set, replacing it with a single new owner
     * @param newOwner The bytes32 ID of the new owner
     */
    function resetOwner(bytes32 newOwner) external;

    /**
     * @notice Provides a list of all added owners
     * @return owners An array of bytes32 IDs representing the owners
     */
    function listOwner() external view returns (bytes32[] memory owners);
}
