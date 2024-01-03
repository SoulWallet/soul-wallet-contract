// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract FallbackManagerSnippet {
    /**
     * @dev Sets the address of the fallback handler contract
     * @param fallbackContract The address of the new fallback handler contract
     */
    function _setFallbackHandler(address fallbackContract) internal virtual;
}
