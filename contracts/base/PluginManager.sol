// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../interfaces/IPluginManager.sol";
import "../interfaces/IPlugin.sol";
import "../libraries/AccountStorage.sol";
import "../authority/Authority.sol";
import "../authority/SafePluginManagerAuth.sol";

abstract contract PluginManager is
    Authority,
    IPluginManager,
    SafePluginManagerAuth
{
    address public immutable safePluginManager;

    constructor(address aSafePluginManager) {
        safePluginManager = aSafePluginManager;
    }

    function _safePluginManager() internal view override returns (address) {
        return safePluginManager;
    }

    function isPlugin(address addr) internal view returns (bool) {
        (addr);
        revert("not implemented");
    }

    function addPlugin(
        IPlugin plugin
    ) external override _onlySafePluginManager {
        emit PluginAdded(plugin);
    }

    function removePlugin(
        IPlugin plugin
    ) external override _onlySafePluginManager {
        emit PluginRemoved(plugin);
    }

    function listPlugin()
        external
        view
        override
        returns (IPlugin[] memory plugins)
    {
        revert("not implemented");
    }

    function preHook(
        address target,
        uint256 value,
        bytes memory data
    ) internal {
        (target, value, data);
    }

    function postHook(
        address target,
        uint256 value,
        bytes memory data
    ) internal {
        (target, value, data);
    }

    function execDelegateCall(IPlugin target, bytes memory data) external {
        _requireFromEntryPointOrOwner();
        isPlugin(address(target));

        //#TODO

        CallHelper.callWithoutReturnData(
            CallHelper.CallType.DELEGATECALL,
            address(target),
            data
        );
    }
}
