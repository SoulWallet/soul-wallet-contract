// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;
import "../interfaces/IPluginManager.sol";
import "../interfaces/IPlugin.sol";
import "../libraries/AccountStorage.sol";
import "../authority/Authority.sol";

abstract contract PluginManager is Authority, IPluginManager {
    bytes4 internal constant FUNC_ADD_PLUGIN =
        bytes4(keccak256("addPlugin(address,bytes)"));
    bytes4 internal constant FUNC_REMOVE_PLUGIN =
        bytes4(keccak256("removePlugin(address)"));

    function addPlugin(Plugin calldata plugin) internal {
        emit PluginAdded(plugin.plugin);
    }

    function removePlugin(IPlugin plugin) internal {
        emit PluginRemoved(plugin);
    }

    function _isAuthorizedPlugin(address plugin) private returns (bool) {
        (plugin);
        revert("not implemented");
    }

    function isAuthorizedPlugin(
        address plugin
    ) external override returns (bool) {
        return _isAuthorizedPlugin(plugin);
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
        require(_isAuthorizedPlugin(address(target)));

        //#TODO

        CallHelper.callWithoutReturnData(
            CallHelper.CallType.DelegateCall,
            address(target),
            data
        );
    }
}
