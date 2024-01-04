// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IHookManager {
    /**
     * @notice Emitted when a hook is installed
     * @param hook hook
     */
    event HookInstalled(address hook);

    /**
     * @notice Emitted when a hook is uninstalled
     * @param hook hook
     */
    event HookUninstalled(address hook);

    /**
     * @notice Emitted when a hook is uninstalled with error
     * @param hook hook
     */
    event HookUninstalledwithError(address hook);

    function uninstallHook(address hookAddress) external;

    function isInstalledHook(address hook) external view returns (bool);

    function listHook()
        external
        view
        returns (address[] memory preIsValidSignatureHooks, address[] memory preUserOpValidationHooks);
}
