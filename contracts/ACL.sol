// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./utils/access/AccessControlEnumerable.sol";


abstract contract ACL is AccessControlEnumerable {
    using ECDSA for bytes32;

    /**
     * @dev Tells whether an account is owner or not
     */
    function isOwner(address account) public view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, account);
    }

    /**
     * @dev Transfers owner permissions from the owner at index #0 to another account
     */
    function transferOwner(address account) external virtual;

}
