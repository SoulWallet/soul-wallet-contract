// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

abstract contract OwnerAuth {
    function _isOwner(address addr) internal view virtual returns (bool);
}