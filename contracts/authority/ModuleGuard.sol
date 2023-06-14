// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./GuardByteSlot.sol";
import "../libraries/Errors.sol";

contract ModuleGuard is GuardByteSlot {
    bytes32 private constant _BYTE_MASK = 0x00ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    modifier moduleHook() {
        bytes32 BIT_SLOT = GuardByteSlot._BIT_SLOT;
        assembly ("memory-safe") {
            // load 32 byte value from slot _BIT_SLOT
            let data := sload(BIT_SLOT)
            // load the first byte, BYTE = (x >> (248 - i * 8)) && 0xFF [x=data,i=0]
            let _byte := byte(0, data)
            // if allready set the bit(_byte == 1), revert
            if eq(_byte, 1) { revert(0, 0) }
            // if not set the bit(_byte == 0), set the bit=1 and store
            data := and(data, _BYTE_MASK)
            data := or(data, shl(248, 1))
            sstore(BIT_SLOT, data)
        }
        _;
        assembly ("memory-safe") {
            let data := sload(BIT_SLOT)
            let _byte := byte(0, data)
            // if not set the bit(_byte == 0), revert
            if eq(_byte, 0) { revert(0, 0) }
            // if allready set the bit(_byte == 1), set the bit=0 and store
            data := and(data, _BYTE_MASK)
            data := or(data, shl(248, 0))
            sstore(BIT_SLOT, data)
        }
    }

    function _callFromModule() internal view returns (bool callFromModule) {
        /*  Equivalent code：
            if (msg.sender != address(this)) {
                return false;
            } else {
                return isInModule();
            }
        */
        bytes32 BIT_SLOT = GuardByteSlot._BIT_SLOT;
        assembly ("memory-safe") {
            if eq(caller(), address()) {
                let _byte := byte(0, sload(BIT_SLOT))
                callFromModule := eq(_byte, 1)
            }
        }
    }

    /*
        Data Flow:

        A: from Module
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
    │ A: Module and Plugin (only delegatecall plugin and plugin contain the DELEGATECALL opcode)        ││
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
    │ B: More...                                                                                        ││
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
    modifier onlyModule() {
        if (!_callFromModule()) {
            revert Errors.CALLER_MUST_BE_MODULE();
        }
        _;
    }
}
