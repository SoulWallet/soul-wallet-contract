// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "../interfaces/IValidator.sol";
/**
 * @title Validator
 * @dev This abstract contract provides a method to retrieve an IValidator interface
 */

abstract contract Validator {
    /**
     * @dev Gets the IValidator interface
     * @return An instance of the IValidator interface
     */
    function validator() public view virtual returns (IValidator);
}
