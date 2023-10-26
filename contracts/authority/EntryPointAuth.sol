// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "../libraries/Errors.sol";

/**
 * @title EntryPointAuth
 * @notice Abstract contract to provide EntryPoint based authentication
 * @dev Requires the inheriting contracts to implement the `_entryPoint` method
 */
abstract contract EntryPointAuth {
    /**
     * @notice Expected to return the associated entry point for the contract
     * @dev Must be implemented by inheriting contracts
     * @return The EntryPoint associated with the contract
     */
    function _entryPoint() internal view virtual returns (IEntryPoint);

    /*
        Data Flow:

        A: from entryPoint
            # msg.sender:    entryPoint
            # address(this): soulwalletProxy
            ┌────────────┐     ┌────────┐
            │ entryPoint │ ──► │  here  │
            └────────────┘     └────────┘
    * @notice Modifier to ensure the caller is the expected entry point
    * @dev If not called from the expected entry point, it will revert
    */
    modifier onlyEntryPoint() {
        if (msg.sender != address(_entryPoint())) {
            revert Errors.CALLER_MUST_BE_ENTRYPOINT();
        }
        _;
    }
}
