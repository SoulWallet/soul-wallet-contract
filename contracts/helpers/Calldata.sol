pragma solidity ^0.8.12;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "solidity-bytes-utils/contracts/BytesLib.sol";
import "../ACL.sol";

library Calldata {
    using SafeMath for uint256;

    /**
     * @dev Tells whether a calldata is calling to the ACL's transfer owner method
     */
    function isTransferOwner(bytes memory self) internal pure returns (bool) {
        return selector(self) == ACL.transferOwner.selector;
    }

    function selector(bytes memory self) internal pure returns (bytes4) {
        return bytes4(BytesLib.slice(self, 0, 4));
    }
}
