// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "./IValidator.sol";

/**
 * @title Validator Manager Interface
 * @dev This interface provides a method to retrieve the active validator instance
 */
interface IValidatorManager {
    /**
     * @dev Returns the current active validator instance
     * @return The active validator instance
     */
    function validator() external view returns (IValidator);
}
