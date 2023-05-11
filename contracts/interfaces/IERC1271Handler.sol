// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/interfaces/IERC1271.sol";

interface IERC1271Handler is IERC1271 {
    event ApproveHash(bytes32 indexed hash);
    event RejectHash(bytes32 indexed hash);

    function approveHash(bytes32 hash) external;
    function rejectHash(bytes32 hash) external;
}