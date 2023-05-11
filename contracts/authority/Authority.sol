// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./EntryPointAuth.sol";
import "./OwnerAuth.sol";

abstract contract Authority is EntryPointAuth, OwnerAuth {
    function _requireFromEntryPointOrOwner() internal view {
        address addr = msg.sender;
        require(
            addr == address(_entryPoint()) || _isOwner(addr),
            "require from Entrypoint or owner"
        );
    }

    function _requireFromEntryPointOrSelf() internal view {
        address addr = msg.sender;
        require(
            addr == address(_entryPoint()) ||
                addr == address(this) ||
                _isOwner(addr),
            "require from Entrypoint or owner or self"
        );
    }

    modifier onlyEntryPointOrOwner() {
        _requireFromEntryPointOrOwner();
        _;
    }

    modifier onlyEntryPointOrSelf() {
        _requireFromEntryPointOrSelf();
        _;
    }
}
