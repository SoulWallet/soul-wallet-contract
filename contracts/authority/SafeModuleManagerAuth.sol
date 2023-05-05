// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

abstract contract SafeModuleManagerAuth {
    function _safeModuleManager() internal view virtual returns (address);

    function _requireFromSafeModuleManager(address addr) internal view {
        require(addr == address(_safeModuleManager()), "require safeModuleManager");
    }

    modifier _onlySafeModuleManager() {
        _requireFromSafeModuleManager(msg.sender);
        _;
    }
}