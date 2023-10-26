// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "./IPluggable.sol";

/**
 * @title Module Interface
 * @dev This interface defines the funcations that a module needed access in the smart contract wallet
 * Modules are key components that can be plugged into the main contract to enhance its functionalities
 * For security reasons, a module can only call functions in the smart contract that it has explicitly
 * listed via the `requiredFunctions` method
 */
interface IModule is IPluggable {
    /**
     * @notice Provides a list of function selectors that the module is allowed to call
     * within the smart contract. When a module is added to the smart contract, it's restricted
     * to only call these functions. This ensures that modules have explicit and limited permissions,
     * enhancing the security of the smart contract (e.g., a "Daily Limit" module shouldn't be able to
     * change the owner)
     *
     * @return An array of function selectors that this module is permitted to call
     */
    function requiredFunctions() external pure returns (bytes4[] memory);
}
