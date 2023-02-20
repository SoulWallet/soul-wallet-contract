// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "./DiamondStorage.sol";
import "@openzeppelin/contracts/utils/Address.sol";

abstract contract DiamondFallback {
    fallback() external payable {
        // inline storage layout retrieval uses less gas
        DiamondStorage.Layout storage l;
        bytes32 slot = DiamondStorage.STORAGE_SLOT;
        assembly {
            l.slot := slot
        }

        // get facet from function selector
        address facet = address(bytes20(l.facets[msg.sig]));
        require(Address.isContract(facet), "Diamond: Function does not exist");
        // Execute external function from facet using delegatecall and return any value.
        assembly {
            // copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
            // execute function call using the facet
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            // get any return value
            returndatacopy(0, 0, returndatasize())
            // return any return value or error back to the caller
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}
