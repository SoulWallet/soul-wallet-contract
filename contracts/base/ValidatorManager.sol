// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "../interfaces/IValidator.sol";
import "./Validator.sol";

/**
 * @title ValidatorManager
 * @dev This abstract contract extends the Validator contract and manages a single instance of IValidator
 */
abstract contract ValidatorManager is Validator {
    /// @dev The IValidator interface instance
    IValidator private immutable _VALIDATOR;
    /**
     * @dev Constructs the ValidatorManager contracs
     * @param aValidator The IValidator interface instance
     */

    constructor(IValidator aValidator) {
        _VALIDATOR = aValidator;
    }
    /**
     * @dev Gets the IValidator interface instance
     * @return The IValidator interface instance
     */

    function validator() public view override returns (IValidator) {
        return _VALIDATOR;
    }
}
