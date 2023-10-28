// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "../interfaces/IFallbackManager.sol";
import "../authority/Authority.sol";
import "../libraries/AccountStorage.sol";

/**
 * @title FallbackManager
 * @notice Manages the fallback behavior for the contract
 * @dev Inherits functionalities from Authority and IFallbackManager
 */
abstract contract FallbackManager is Authority, IFallbackManager {
    /// @notice A payable function that allows the contract to receive ether
    receive() external payable {}

    /**
     * @dev Sets the address of the fallback handler contract
     * @param fallbackContract The address of the new fallback handler contract
     */
    function _setFallbackHandler(address fallbackContract) internal {
        AccountStorage.layout().defaultFallbackContract = fallbackContract;
    }

    /**
     * @notice Fallback function that forwards all requests to the fallback handler contract
     * @dev The request is forwarded using a STATICCALL
     * It ensures that the state of the contract doesn't change even if the fallback function has state-changing operations
     */
    fallback() external payable {
        address fallbackContract = AccountStorage.layout().defaultFallbackContract;
        assembly {
            /* not memory-safe */
            calldatacopy(0, 0, calldatasize())
            let result := staticcall(gas(), fallbackContract, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    /**
     * @notice Sets the address of the fallback handler and emits the FallbackChanged event
     * @param fallbackContract The address of the new fallback handler
     */
    function setFallbackHandler(address fallbackContract) external override onlySelfOrModule {
        _setFallbackHandler(fallbackContract);
        emit FallbackChanged(fallbackContract);
    }
}
