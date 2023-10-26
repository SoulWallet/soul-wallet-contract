// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;
/**
 * @title IL1Block
 * @notice Interface for representing Layer 1 block properties, primarily block hash and block number
 */

interface IL1Block {
    /**
     * @dev Fetches the hash of the L1 block
     * @return The block hash as bytes32
     */
    function hash() external returns (bytes32);
    /**
     * @dev Fetches the number of the L1 block
     * @return The block number as uint256
     */
    function number() external returns (uint256);
}
