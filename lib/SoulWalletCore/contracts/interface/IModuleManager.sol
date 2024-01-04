// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IModuleManager {
    /**
     * @notice Emitted when a module is installed
     * @param module module
     */
    event ModuleInstalled(address module);

    /**
     * @notice Emitted when a module is uninstalled
     * @param module module
     */
    event ModuleUninstalled(address module);

    /**
     * @notice Emitted when a module is uninstalled with error
     * @param module module
     */
    event ModuleUninstalledwithError(address module);

    function uninstallModule(address moduleAddress) external;

    function isInstalledModule(address module) external view returns (bool);

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
