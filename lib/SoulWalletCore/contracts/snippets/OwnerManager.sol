// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract OwnerManagerSnippet {
    /**
     * @dev Helper function to get the owner mapping from account storage
     * @return owners Mapping of current owners
     */
    function _ownerMapping() internal view virtual returns (mapping(bytes32 => bytes32) storage owners);

    /**
     * @dev Checks if the provided owner is a current owner
     * @param owner Address in bytes32 format to check
     * @return true if provided owner is a current owner, false otherwise
     */
    function _isOwner(bytes32 owner) internal view virtual returns (bool);

    /**
     * @dev Add an owner
     * @param owner Address in bytes32 format to add
     */
    function _addOwner(bytes32 owner) internal virtual;

    /**
     * @dev Remove an owner
     * @param owner Address in bytes32 format to remove
     */
    function _removeOwner(bytes32 owner) internal virtual;

    /**
     * @dev Reset owner
     */
    function _resetOwner(bytes32 newOwner) internal virtual;

    /**
     * @dev Clear owner
     */
    function _clearOwner() internal virtual;
}
