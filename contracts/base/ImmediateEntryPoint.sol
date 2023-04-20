// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../account-abstraction/contracts/interfaces/IEntryPoint.sol";

abstract contract ImmediateEntryPoint {
    
    IEntryPoint private immutable __entryPoint;

    constructor(IEntryPoint anEntryPoint) {
        __entryPoint = anEntryPoint;
    }

    function _getEntryPoint() internal view returns (IEntryPoint) {
        return __entryPoint;
    }

}
