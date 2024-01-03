// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IValidator} from "./IValidator.sol";

interface IValidatorManager {
    /**
     * @notice Emitted when a validator is installed
     * @param validator Validator
     */
    event ValidatorInstalled(address validator);

    /**
     * @notice Emitted when a validator is uninstalled
     * @param validator Validator
     */
    event ValidatorUninstalled(address validator);

    /**
     * @notice Emitted when a validator is uninstalled with error
     * @param validator Validator
     */
    event ValidatorUninstalledwithError(address validator);

    function uninstallValidator(address validator) external;

    function listValidator() external view returns (address[] memory validators);
}
