
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "../interfaces/IKeyStoreValidatorManager.sol";


abstract contract BaseKeyStoreValidatorManager is IKeyStoreValidatorManager {
    IKeyStoreValidator private immutable _VALIDATOR;
      constructor(IKeyStoreValidator aValidator) {
        _VALIDATOR = aValidator;
    }
    function validator() public view override returns (IKeyStoreValidator) {
        return _VALIDATOR;
    }
}
