// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {IHook} from "../../contracts/interface/IHook.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {IStandardExecutor, Execution} from "../../contracts/interface/IStandardExecutor.sol";
import {IHookManager} from "../../contracts/interface/IHookManager.sol";

/**
 * @dev DemoHook is a simple example of a hook that can be used to block any transfers over 1 ETH.
 */
contract DemoHook is IHook {
    event InitCalled(bytes data);
    event DeInitCalled();

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IHook).interfaceId;
    }

    function Init(bytes calldata data) external override {
        IHookManager hookManager = IHookManager(msg.sender);
        require(hookManager.isInstalledHook(address(this)) == true, "DemoHook: not registered");

        emit InitCalled(data);
    }

    function DeInit() external override {
        IHookManager hookManager = IHookManager(msg.sender);
        require(hookManager.isInstalledHook(address(this)) == false, "DemoHook: still registered");
        emit DeInitCalled();
    }

    function preIsValidSignatureHook(bytes32 hash, bytes calldata hookSignature) external pure override {
        // skip EIP1271 Hook
        (hash, hookSignature);
        require(hookSignature.length == 0, "DemoHook does not need a signature");
    }

    function preUserOpValidationHook(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds,
        bytes calldata hookSignature
    ) external pure override {
        (userOpHash, missingAccountFunds, hookSignature);
        require(hookSignature.length == 0, "DemoHook does not need a signature");
        // Block any transfers over 1 ETH
        bytes4 selector = bytes4(userOp.callData);
        if (IStandardExecutor.execute.selector == selector) {
            // function execute(address target, uint256 value, bytes calldata data)
            (, uint256 value,) = abi.decode(userOp.callData[4:], (address, uint256, bytes));
            require(value <= 1 ether, "DemoHook: transfer value too high");
        } else if (IStandardExecutor.executeBatch.selector == selector) {
            // function executeBatch(Execution[] calldata executions)
            (Execution[] memory executions) = abi.decode(userOp.callData[4:], (Execution[]));
            uint256 value;
            for (uint256 i = 0; i < executions.length; i++) {
                value += executions[i].value;
            }
            require(value <= 1 ether, "DemoHook: transfer value too high");
        }
    }
}
