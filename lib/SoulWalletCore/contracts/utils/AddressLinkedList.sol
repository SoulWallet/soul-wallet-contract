// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title Address Linked List
 * @notice This library provides utility functions to manage a linked list of addresses
 */
library AddressLinkedList {
    error INVALID_ADDRESS();
    error ADDRESS_ALREADY_EXISTS();
    error ADDRESS_NOT_EXISTS();

    address internal constant SENTINEL_ADDRESS = address(1);
    uint160 internal constant SENTINEL_UINT = 1;

    /**
     * @dev Modifier that checks if an address is valid.
     */
    modifier onlyAddress(address addr) {
        if (uint160(addr) <= SENTINEL_UINT) {
            revert INVALID_ADDRESS();
        }
        _;
    }
    /**
     * @notice Adds an address to the linked list.
     * @param self The linked list mapping.
     * @param addr The address to be added.
     */

    function add(mapping(address => address) storage self, address addr) internal onlyAddress(addr) {
        if (self[addr] != address(0)) {
            revert ADDRESS_ALREADY_EXISTS();
        }
        address _prev = self[SENTINEL_ADDRESS];
        if (_prev == address(0)) {
            self[SENTINEL_ADDRESS] = addr;
            self[addr] = SENTINEL_ADDRESS;
        } else {
            self[SENTINEL_ADDRESS] = addr;
            self[addr] = _prev;
        }
    }

    /**
     * @notice Removes an address from the linked list.
     * @param self The linked list mapping.
     * @param addr The address to be removed.
     */

    function remove(mapping(address => address) storage self, address addr) internal {
        if (!tryRemove(self, addr)) {
            revert ADDRESS_NOT_EXISTS();
        }
    }
    /**
     * @notice Tries to remove an address from the linked list.
     * @param self The linked list mapping.
     * @param addr The address to be removed.
     * @return Returns true if removal is successful, false otherwise.
     */

    function tryRemove(mapping(address => address) storage self, address addr) internal returns (bool) {
        if (isExist(self, addr)) {
            address cursor = SENTINEL_ADDRESS;
            while (true) {
                address _addr = self[cursor];
                if (_addr == addr) {
                    address next = self[_addr];
                    self[cursor] = next;
                    self[_addr] = address(0);
                    return true;
                }
                cursor = _addr;
            }
        }
        return false;
    }
    /**
     * @notice Clears all addresses from the linked list.
     * @param self The linked list mapping.
     */

    function clear(mapping(address => address) storage self) internal {
        address addr = self[SENTINEL_ADDRESS];
        self[SENTINEL_ADDRESS] = address(0);
        while (uint160(addr) > SENTINEL_UINT) {
            address _addr = self[addr];
            self[addr] = address(0);
            addr = _addr;
        }
    }
    /**
     * @notice Checks if an address exists in the linked list.
     * @param self The linked list mapping.
     * @param addr The address to check.
     * @return Returns true if the address exists, false otherwise.
     */

    function isExist(mapping(address => address) storage self, address addr)
        internal
        view
        onlyAddress(addr)
        returns (bool)
    {
        return self[addr] != address(0);
    }
    /**
     * @notice Returns the size of the linked list.
     * @param self The linked list mapping.
     * @return Returns the size of the linked list.
     */

    function size(mapping(address => address) storage self) internal view returns (uint256) {
        uint256 result = 0;
        address addr = self[SENTINEL_ADDRESS];
        while (uint160(addr) > SENTINEL_UINT) {
            addr = self[addr];
            unchecked {
                result++;
            }
        }
        return result;
    }
    /**
     * @notice Checks if the linked list is empty.
     * @param self The linked list mapping.
     * @return Returns true if the linked list is empty, false otherwise.
     */

    function isEmpty(mapping(address => address) storage self) internal view returns (bool) {
        return self[SENTINEL_ADDRESS] == address(0);
    }

    /**
     * @notice Returns a list of addresses from the linked list.
     * @param self The linked list mapping.
     * @param from The starting address.
     * @param limit The number of addresses to return.
     * @return Returns an array of addresses.
     */
    function list(mapping(address => address) storage self, address from, uint256 limit)
        internal
        view
        returns (address[] memory)
    {
        address[] memory result = new address[](limit);
        uint256 i = 0;
        address addr = self[from];
        while (uint160(addr) > SENTINEL_UINT && i < limit) {
            result[i] = addr;
            addr = self[addr];
            unchecked {
                i++;
            }
        }

        return result;
    }
}
