// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Authority} from "./Authority.sol";

abstract contract EntryPointManager is Authority {
    /**
     * @dev use immutable to save gas
     */
    address internal immutable _ENTRY_POINT;

    /**
     * a custom error for caller must be entry point
     */
    error CALLER_MUST_BE_ENTRY_POINT();

    constructor(address _entryPoint) {
        _ENTRY_POINT = _entryPoint;
    }

    function entryPoint() external view returns (address) {
        return _ENTRY_POINT;
    }

    /**
     * @notice Ensures the calling contract is the entrypoint
     */
    function _onlyEntryPoint() internal view override {
        if (msg.sender != _ENTRY_POINT) {
            revert CALLER_MUST_BE_ENTRY_POINT();
        }
    }
}
