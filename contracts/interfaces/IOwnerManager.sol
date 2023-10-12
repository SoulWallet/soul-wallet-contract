// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

interface IOwnerManager {
    event OwnerAdded(bytes32 indexed owner);
    event OwnerRemoved(bytes32 indexed owner);
    event OwnerCleared();

    function isOwner(bytes32 owner) external view returns (bool);
    function addOwner(bytes32 owner) external;
    function removeOwner(bytes32 owner) external;
    function resetOwner(bytes32 newOwner) external;
    function addOwners(bytes32[] calldata owners) external;
    function resetOwners(bytes32[] calldata newOwners) external;
    function listOwner() external view returns (bytes32[] memory owners);
}
