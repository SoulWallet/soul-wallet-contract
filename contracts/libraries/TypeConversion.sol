// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;
/**
 * @title TypeConversion
 * @notice A library to facilitate address to bytes32 conversions
 */

library TypeConversion {
    /**
     * @notice Converts an address to bytes32
     * @param addr The address to be converted
     * @return Resulting bytes32 representation of the input address
     */
    function toBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }
    /**
     * @notice Converts an array of addresses to an array of bytes32
     * @param addresses Array of addresses to be converted
     * @return Array of bytes32 representations of the input addresses
     */

    function addressesToBytes32Array(address[] memory addresses) internal pure returns (bytes32[] memory) {
        bytes32[] memory result = new bytes32[](addresses.length);
        for (uint256 i = 0; i < addresses.length; i++) {
            result[i] = toBytes32(addresses[i]);
        }
        return result;
    }
}
