// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "../authority/EntryPointAuth.sol";

abstract contract EntryPointManager is EntryPointAuth {
    IEntryPoint private immutable _ENTRY_POINT;

    constructor(IEntryPoint entryPoint) {
        _ENTRY_POINT = entryPoint;
    }

    function _entryPoint() internal view override returns (IEntryPoint) {
        return _ENTRY_POINT;
    }
}
