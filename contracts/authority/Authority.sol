// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./EntryPointAuth.sol";
import "./OwnerAuth.sol";
import "../interfaces/IExecutionManager.sol";
import "../interfaces/IModuleManager.sol";
import "./ModuleGuard.sol";
import "./ExecutionManagerGuard.sol";

abstract contract Authority is EntryPointAuth, OwnerAuth, ModuleGuard, ExecutionManagerGuard {
    /*
        Data Flow:

        A: from entryPoint
            # msg.sender:    soulwalletProxy
            # address(this): soulwalletProxy
            ┌────────────┐     ┌───────────────────────────┐     ┌──────┐
            │ entryPoint │ ──► │ ExecutionManager::execute │ ──► │ here │
            └────────────┘     └───────────────────────────┘     └──────┘


        D: off-chain simulate
            # msg.sender:    address(0)
            # address(this): soulwalletProxy
            ┌────────────┐     ┌──────┐
            │ address(0) │ ──► │ here │
            └────────────┘     └──────┘

    ┌───────────────────────────────────────────────────────────────────────────────────────────────────┐
    │                                                                                                   ├┐
    │ # In addition, the following data flow may be exist:                                              ││
    │                                                                                                   ││
    │ A: Plugin (only delegatecall plugin and plugin contain the DELEGATECALL opcode)                   ││
    │     # msg.sender:    soulwalletProxy                                                              ││
    │     # address(this): soulwalletProxy                                                              ││
    │     ┌───────────────────────────┐     ┌───────────────────────────────────────────┐     ┌──────┐  ││
    │     │ ExecutionManager::execute │ ──► │ Plugin(preHook|postHook|execDelegateCall) │ ──► │ here │  ││
    │     └───────────────────────────┘     └───────────────────────────────────────────┘     └──────┘  ││
    │                                                                                                   ││
    │ B: Module and Plugin (only delegatecall plugin and plugin contain the DELEGATECALL opcode)        ││
    │     # msg.sender:    soulwalletProxy                                                              ││
    │     # address(this): soulwalletProxy                                                              ││
    │     ┌───────────────────────────┐     ┌────────┐     ┌─────────────────────────────────┐          ││
    │     │ ExecutionManager::execute │ ──► │ Module │ ──► │ ModuleManager::moduleEntryPoint │          ││
    │     └───────────────────────────┘     └────────┘     └─────────────────┬───────────────┘          ││
    │                 ┌──────────────────────────────────────────────────────┘                          ││
    │                 ▼                                                                                 ││
    │     ┌──────────────────────┐     ┌──────┐                                                         ││
    │     │ Plugin (Init/DeInit) │ ──► │ here │                                                         ││
    │     └──────────────────────┘     └──────┘                                                         ││
    │                                                                                                   ││
    │ C: More...                                                                                        ││
    │                                                                                                   ││
    │ However, they can be avoided by prohibit adding plugin that contain F4 (DELEGATECALL) opcode:     ││
    │ 1. If a user add a plugin via the soulwallet frontend,the addition is prohibited                  ││
    │    if DELEGATECALL opcode is found in plugin.                                                     ││
    │ 2. If a hacker steals your account and add plugin directly via contract,then hacker also          ││
    │    needs to wait 48 hours(During this period, users can regain control of the account             ││
    │    through social recovery and interrupt the process).                                            ││
    │                                                                                                   ││
    └───────────────────────────────────────────────────────────────────────────────────────────────────┘
    */
    modifier onlyExecutionManagerOrSimulate() {
        require(_callFromExecutionManager() || msg.sender == address(0), "require from Entrypoint or Simulate");
        _;
    }

    /*
        Data Flow:

        A: from entryPoint
            # msg.sender:    soulwalletProxy
            # address(this): soulwalletProxy
            ┌────────────┐     ┌───────────────────────────┐     ┌──────┐
            │ entryPoint │ ──► │ ExecutionManager::execute │ ──► │ here │
            └────────────┘     └───────────────────────────┘     └──────┘

        B: from Module
            # msg.sender:    soulwalletProxy
            # address(this): soulwalletProxy
            ┌───────────────────────────┐     ┌──────────────────┐
            │ ExecutionManager::execute │ ──► │                  │
            └───────────────────────────┘     │                  │
                                              │  Module Contract │──┐
            ┌───────────────┐                 │                  │  │
            │ Other Account │ ──────────────► │                  │  │
            └───────────────┘                 └──────────────────┘  │
                                                                    │
                                                                    │
                                   ┌────────────────────────────────┘
                                   │
                                   ▼
            ┌─────────────────────────────────┐     ┌──────┐
            | ModuleManager::moduleEntryPoint | ──► | here |
            └─────────────────────────────────┘     └──────┘


    ┌───────────────────────────────────────────────────────────────────────────────────────────────────┐
    │                                                                                                   ├┐
    │ # In addition, the following data flow may be exist:                                              ││
    │                                                                                                   ││
    │ A: Plugin (only delegatecall plugin and plugin contain the DELEGATECALL opcode)                   ││
    │     # msg.sender:    soulwalletProxy                                                              ││
    │     # address(this): soulwalletProxy                                                              ││
    │     ┌───────────────────────────┐     ┌───────────────────────────────────────────┐     ┌──────┐  ││
    │     │ ExecutionManager::execute │ ──► │ Plugin(preHook|postHook|execDelegateCall) │ ──► │ here │  ││
    │     └───────────────────────────┘     └───────────────────────────────────────────┘     └──────┘  ││
    │                                                                                                   ││
    │ B: Module and Plugin (only delegatecall plugin and plugin contain the DELEGATECALL opcode)        ││
    │     # msg.sender:    soulwalletProxy                                                              ││
    │     # address(this): soulwalletProxy                                                              ││
    │     ┌───────────────────────────┐     ┌────────┐     ┌─────────────────────────────────┐          ││
    │     │ ExecutionManager::execute │ ──► │ Module │ ──► │ ModuleManager::moduleEntryPoint │          ││
    │     └───────────────────────────┘     └────────┘     └─────────────────┬───────────────┘          ││
    │                 ┌──────────────────────────────────────────────────────┘                          ││
    │                 ▼                                                                                 ││
    │     ┌──────────────────────┐     ┌──────┐                                                         ││
    │     │ Plugin (Init/DeInit) │ ──► │ here │                                                         ││
    │     └──────────────────────┘     └──────┘                                                         ││
    │                                                                                                   ││
    │ C: More...                                                                                        ││
    │                                                                                                   ││
    │ However, they can be avoided by prohibit adding plugin that contain F4 (DELEGATECALL) opcode:     ││
    │ 1. If a user add a plugin via the soulwallet frontend,the addition is prohibited                  ││
    │    if DELEGATECALL opcode is found in plugin.                                                     ││
    │ 2. If a hacker steals your account and add plugin directly via contract,then hacker also          ││
    │    needs to wait 48 hours(During this period, users can regain control of the account             ││
    │    through social recovery and interrupt the process).                                            ││
    │                                                                                                   ││
    └───────────────────────────────────────────────────────────────────────────────────────────────────┘
    */
    modifier onlyExecutionManagerOrModule() {
        require(_callFromExecutionManager() || _callFromModule(), "require from ExecutionManager or Module");
        _;
    }
}
