// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../interfaces/IFallbackManager.sol";

contract FallbackManager is IFallbackManager {
    receive() external payable {}

    fallback() external payable {
        // all requests are forwarded to the fallback contract use STATICCALL
        // to avoid reentrancy
        address fallbackContract = address(1);
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := staticcall(
                gas(),
                fallbackContract,
                0,
                calldatasize(),
                0,
                0
            )
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    function setFallback(address fallbackContract) external override {
        (fallbackContract);
        revert("not implemented");
    }
}
