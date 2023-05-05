// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

abstract contract GuardianManagerAuth {
    function _guardianManager() internal view virtual returns (address);

    function _requireFromGuardianManager(address addr) internal view {
        require(addr == address(_guardianManager()), "require guardianManager");
    }

    modifier _onlyGuardianManager() {
        _requireFromGuardianManager(msg.sender);
        _;
    }
}