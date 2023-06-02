// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../authority/EntryPointAuth.sol";

abstract contract EntryPointManager is EntryPointAuth {
    IEntryPoint private immutable _ENTRY_POINT;

    constructor(IEntryPoint anEntryPoint) {
        _ENTRY_POINT = anEntryPoint;
    }

    function _entryPoint() internal view override returns (IEntryPoint) {
        return _ENTRY_POINT;
    }
}
