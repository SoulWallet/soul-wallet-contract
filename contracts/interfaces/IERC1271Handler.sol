// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/interfaces/IERC1271.sol";

/**
 * @title IERC1271Handler
 * @dev This interface extends the IERC1271 interface by adding functionality to approve and reject hashes
 * The main intention is to manage the approval status of specific signed hashes
 */
interface IERC1271Handler is IERC1271 {
    /**
     * @dev Emitted when a hash has been approved.
     * @param hash The approved hash.
     */
    event ApproveHash(bytes32 indexed hash);
    /**
     * @dev Emitted when a hash has been rejected
     * @param hash The rejected hash
     */
    event RejectHash(bytes32 indexed hash);
    /**
     * @notice Approves the given hash
     * @param hash The hash to approve
     */

    function approveHash(bytes32 hash) external;
    /**
     * @notice Rejects the given hash
     * @param hash The hash to reject
     */
    function rejectHash(bytes32 hash) external;
}
