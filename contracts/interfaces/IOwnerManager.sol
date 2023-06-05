// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

interface IOwnerManager {
    event OwnerCleared();
    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);

    function isOwner(address addr) external view returns (bool);

    function resetOwner(address newOwner) external;

    function addOwner(address owner) external;

    function addOwners(address[] calldata owners) external;

    function resetOwners(address[] calldata newOwners) external;

    function removeOwner(address owner) external;

    function listOwner() external returns (address[] memory owners);
}
