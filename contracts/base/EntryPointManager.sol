// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../authority/EntryPointAuth.sol";

abstract contract EntryPointManager is EntryPointAuth {
    IEntryPoint private immutable __entryPoint;

    constructor(IEntryPoint anEntryPoint) {
        __entryPoint = anEntryPoint;
    }

    function _entryPoint() internal view override returns (IEntryPoint) {
        return __entryPoint;
    }
}
