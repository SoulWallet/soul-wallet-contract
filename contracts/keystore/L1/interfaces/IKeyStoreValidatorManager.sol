
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;
import "./IKeyStoreValidator.sol";

interface IKeyStoreValidatorManager {
    function validator() external view returns (IKeyStoreValidator);
}
