// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../interfaces/UserOperation.sol";

interface IValidator {

    /**
     * @dev Returns true if the user operation initCode is in trusted list.
     */
    function validate(UserOperation memory _op) external pure returns (bool);
    
}
