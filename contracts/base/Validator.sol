// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "../interfaces/IValidator.sol";

abstract contract Validator {
    function validator() public view virtual returns (IValidator);
}
