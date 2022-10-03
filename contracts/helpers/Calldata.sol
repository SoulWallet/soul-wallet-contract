pragma solidity ^0.8.12;

import "../ACL.sol";

library Calldata {
    /**
     * @dev Tells whether a calldata is calling to the ACL's transfer owner method
     */
    function isTransferOwner(bytes memory self) internal pure returns (bool) {
        return selector(self) == ACL.transferOwner.selector;
    }

    function selector(bytes memory self) internal pure returns (bytes4) {
        return bytes4(self);
    }
}
