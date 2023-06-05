// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./EntryPointAuth.sol";
import "./OwnerAuth.sol";
import "../interfaces/IExecutionManager.sol";
import "../interfaces/IModuleManager.sol";
import "./ModuleGuard.sol";
import "./ExecutionManagerGuard.sol";

abstract contract Authority is EntryPointAuth, OwnerAuth, ModuleGuard, ExecutionManagerGuard {
    modifier onlyEntryPointOrSimulate() {
        require(msg.sender == address(_entryPoint()) || msg.sender == address(0), "require from Entrypoint or Simulate");
        _;
    }

    modifier onlyExecutionManagerOrModule() {
        require(_isExecutionManager() || _isInModule(), "require from ExecutionManager or Module");
        _;
    }
}
