// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./IValidator.sol";

interface IValidatorManager {
    function validator() external view returns (IValidator);
}
