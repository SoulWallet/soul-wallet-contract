// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

abstract contract SafePluginManagerAuth {
    function _safePluginManager() internal view virtual returns (address);

    function _requireFromSafePluginManager(address addr) internal view {
        require(addr == address(_safePluginManager()), "require safePluginManager");
    }

    modifier _onlySafePluginManager() {
        _requireFromSafePluginManager(msg.sender);
        _;
    }
}