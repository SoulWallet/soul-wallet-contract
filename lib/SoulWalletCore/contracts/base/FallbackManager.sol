// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Authority} from "./Authority.sol";
import {IFallbackManager} from "../interface/IFallbackManager.sol";
import {AccountStorage} from "../utils/AccountStorage.sol";
import {FallbackManagerSnippet} from "../snippets/FallbackManager.sol";

abstract contract FallbackManager is IFallbackManager, Authority, FallbackManagerSnippet {
    receive() external payable virtual {}

    /**
     * @dev Sets the address of the fallback handler contract
     * @param fallbackContract The address of the new fallback handler contract
     */
    function _setFallbackHandler(address fallbackContract) internal virtual override {
        AccountStorage.layout().defaultFallbackContract = fallbackContract;
    }

    /**
     * @notice Fallback function that forwards all requests to the fallback handler contract
     * @dev The request is forwarded using a STATICCALL
     * It ensures that the state of the contract doesn't change even if the fallback function has state-changing operations
     */
    fallback() external payable virtual {
        address fallbackContract = AccountStorage.layout().defaultFallbackContract;
        assembly ("memory-safe") {
            function allocate(length) -> pos {
                pos := mload(0x40)
                mstore(0x40, add(pos, length))
            }

            if iszero(fallbackContract) { return(0, 0) }
            let calldataPtr := allocate(calldatasize())
            calldatacopy(calldataPtr, 0, calldatasize())

            let result := staticcall(gas(), fallbackContract, calldataPtr, calldatasize(), 0, 0)

            let returndataPtr := allocate(returndatasize())
            returndatacopy(returndataPtr, 0, returndatasize())

            if iszero(result) { revert(returndataPtr, returndatasize()) }
            return(returndataPtr, returndatasize())
        }
    }

    /**
     * @notice Sets the address of the fallback handler and emits the FallbackChanged event
     * @param fallbackContract The address of the new fallback handler
     */
    function setFallbackHandler(address fallbackContract) external virtual override {
        fallbackManagementAccess();
        _setFallbackHandler(fallbackContract);
        emit FallbackChanged(fallbackContract);
    }
}
