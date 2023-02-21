// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

library DiamondStorage {
    struct Layout {
        // function selector => (facet address, selector slot position)
        mapping(bytes4 => bytes32) facets;
        // total number of selectors registered
        uint16 selectorCount;
        // array of selector slots with 8 selectors per slot
        mapping(uint256 => bytes32) selectorSlots;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256("soulwallet.contracts.diamond.DiamondStorage");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
