// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../libraries/AccountStorage.sol";
import "./EntryPointBase.sol";

abstract contract AccountManager is EntryPointBase {

    function _requireFromOwner() internal view {
        require(
            msg.sender == AccountStorage.layout().owner ||
                msg.sender == address(this),
            "only owner"
        );
    }

    // Require the function call went through EntryPoint or Owner
    function _requireFromEntryPointOrOwner() internal view {
        require(
            msg.sender == address(entryPoint()) ||
                msg.sender == AccountStorage.layout().owner,
            "not Owner or EntryPoint"
        );
    }

    function addOwner(address _add) public {
        _requireFromEntryPointOrOwner();
        (_add);
    }

    function removeOwner(address _delete) public {
        _requireFromEntryPointOrOwner();
        (_delete);
    }

    function resetOwner(
        address[] calldata _add,
        address[] calldata _delete
    ) public {
        _requireFromEntryPointOrOwner();
        (_add, _delete);
    }
}
