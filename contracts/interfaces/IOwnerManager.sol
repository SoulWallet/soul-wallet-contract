// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title Owner Manager Interface
 * @dev This interface defines the management functionalities for handling owners within the system.
 * Owners are identified by a unique bytes32 ID. This design allows for a flexible representation
 * of ownership – whether it be an Ethereum address, a hash of an off-chain public key, or any other
 * unique identifier.
 */
interface IOwnerManager {
    /**
     * @notice Emitted when a new owner is successfully added
     * @param owner The bytes32 ID of the newly added owner
     */
    event OwnerAdded(bytes32 indexed owner);

    /**
     * @notice Emitted when an owner is successfully removed
     * @param owner The bytes32 ID of the removed owner
     */
    event OwnerRemoved(bytes32 indexed owner);

    /**
     * @notice Emitted when all owners are cleared from the system
     */
    event OwnerCleared();

    /**
     * @notice Checks if a given bytes32 ID corresponds to an owner within the system
     * @param owner The bytes32 ID to check
     * @return True if the ID corresponds to an owner, false otherwise
     */
    function isOwner(bytes32 owner) external view returns (bool);

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
     * @notice Adds multiple new owners to the system
     * @param owners An array of bytes32 IDs representing the owners to be added
     */
    function addOwners(bytes32[] calldata owners) external;

    /**
     * @notice Resets the entire owner set, replacing it with a new set of owners
     * @param newOwners An array of bytes32 IDs representing the new set of owners
     */
    function resetOwners(bytes32[] calldata newOwners) external;

    /**
     * @notice Provides a list of all added owners
     * @return owners An array of bytes32 IDs representing the owners
     */
    function listOwner() external view returns (bytes32[] memory owners);
}
