// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../interfaces/IValidator.sol";

abstract contract Validator {
    function validator() public view virtual returns (IValidator);
}
