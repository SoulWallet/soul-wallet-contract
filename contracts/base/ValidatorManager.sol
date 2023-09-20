// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../interfaces/IValidator.sol";
import "./Validator.sol";

abstract contract ValidatorManager is Validator {
    IValidator private immutable _VALIDATOR;

    constructor(IValidator aValidator) {
        _VALIDATOR = aValidator;
    }

    function validator() public view override returns (IValidator) {
        return _VALIDATOR;
    }
}
