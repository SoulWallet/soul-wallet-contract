// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../authority/Authority.sol";
import "./PluginManager.sol";
import "../interfaces/IExecutionManager.sol";
import "./InternalExecutionManager.sol";

abstract contract ExecutionManager is
    IExecutionManager,
    Authority,
    PluginManager,
    InternalExecutionManager
{
    function _blockSelf(address to) private view {
        require(to != address(this), "can not call self");
    }

    /**
     * execute a transaction (called directly from owner, or by entryPoint)
     */
    function _execute(
        address dest,
        uint256 value,
        bytes memory func
    ) internal override {
        _blockSelf(dest);
        _call(dest, value, func);
    }

    /**
     * execute a sequence of transactions
     */
    function _executeBatch(
        address[] memory dest,
        bytes[] memory func
    ) internal override {
        require(dest.length == func.length, "wrong array lengths");
        for (uint256 i = 0; i < dest.length; i++) {
            address to = dest[i];
            _blockSelf(to);
            _call(to, 0, func[i]);
        }
    }

    /**
     * execute a sequence of transactions
     */
    function _executeBatch(
        address[] memory dest,
        uint256[] memory value,
        bytes[] memory func
    ) internal override {
        require(
            dest.length == func.length && dest.length == value.length,
            "wrong array lengths"
        );
        for (uint256 i = 0; i < dest.length; i++) {
            address to = dest[i];
            _blockSelf(to);
            _call(to, value[i], func[i]);
        }
    }

    /**
     * execute a transaction (called directly from owner, or by entryPoint)
     */
    function execute(
        address dest,
        uint256 value,
        bytes calldata func
    ) external override onlyEntryPointOrOwner {
        _call(dest, value, func);
    }

    /**
     * execute a sequence of transactions
     */
    function executeBatch(
        address[] calldata dest,
        bytes[] calldata func
    ) external override onlyEntryPointOrOwner {
        for (uint256 i = 0; i < dest.length; i++) {
            _call(dest[i], 0, func[i]);
        }
    }

    /**
     * execute a sequence of transactions
     */
    function executeBatch(
        address[] calldata dest,
        uint256[] calldata value,
        bytes[] calldata func
    ) external override onlyEntryPointOrOwner {
        for (uint256 i = 0; i < dest.length; i++) {
            _call(dest[i], value[i], func[i]);
        }
    }

    function _call(address target, uint256 value, bytes memory data) private {
        preHook(target, value, data);
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
        postHook(target, value, data);
    }
}
