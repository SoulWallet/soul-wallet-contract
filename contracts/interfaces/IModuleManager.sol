// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "./IModule.sol";

/**
 * @title Module Manager Interface
 * @dev This interface defines the management functionalities for handling modules
 * within the system. Modules are components that can be added to or removed from the
 * smart contract to extend its functionalities. The manager ensures that only authorized
 * modules can execute certain functionalities
 */
interface IModuleManager {
    /**
     * @notice Emitted when a new module is successfully added
     * @param module The address of the newly added module
     */
    event ModuleAdded(address indexed module);
    /**
     * @notice Emitted when a module is successfully removed
     * @param module The address of the removed module
     */
    event ModuleRemoved(address indexed module);
    /**
     * @notice Emitted when there's an error while removing a module
     * @param module The address of the module that was attempted to be removed
     */
    event ModuleRemovedWithError(address indexed module);

    /**
     * @notice Adds a new module to the system
     * @param moduleAndData The module to be added and its associated initialization data
     */
    function addModule(bytes calldata moduleAndData) external;
    /**
     * @notice Removes a module from the system
     * @param  module The address of the module to be removed
     */
    function removeModule(address module) external;

    /**
     * @notice Checks if a module is authorized within the system
     * @param module The address of the module to check
     * @return True if the module is authorized, false otherwise
     */
    function isAuthorizedModule(address module) external returns (bool);
    /**
     * @notice Provides a list of all added modules and their respective authorized function selectors
     * @return modules An array of the addresses of all added modules
     * @return selectors A 2D array where each inner array represents the function selectors
     * that the corresponding module in the 'modules' array is allowed to call
     */
    function listModule() external view returns (address[] memory modules, bytes4[][] memory selectors);
    /**
     * @notice Allows a module to execute a function within the system. This ensures that the
     * module can only call functions it is permitted to, based on its declared `requiredFunctions`
     * @param dest The address of the destination contract where the function will be executed
     * @param value The amount of ether (in wei) to be sent with the function call
     * @param func The function data to be executed
     */
    function executeFromModule(address dest, uint256 value, bytes calldata func) external;
}
