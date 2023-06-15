// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../libraries/Errors.sol";

abstract contract ModuleAuth {
    function _isAuthorizedModule() internal view virtual returns (bool);

    modifier onlyModule() {
        if (!_isAuthorizedModule()) {
            revert Errors.CALLER_MUST_BE_MODULE();
        }
        _;
    }
}
