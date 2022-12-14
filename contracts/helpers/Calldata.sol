// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "../ACL.sol";

library Calldata {
    /**
     * @dev Tells whether a calldata is calling to the ACL's transfer owner method
     */
    function isTransferOwner(bytes memory self) internal pure returns (bool) {
        return bytes4(self) == ACL.transferOwner.selector;
    }
}
