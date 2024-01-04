// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract ModuleManagerSnippet {
    /**
     * @dev checks whether a address is a authorized module
     */
    function _isInstalledModule(address module) internal view virtual returns (bool);

    /**
     * @dev checks whether a address is a module
     * note: If you need to extend the interface, override this function
     * @param moduleAddress module address
     */
    function _isSupportsModuleInterface(address moduleAddress) internal view virtual returns (bool);

    /**
     * @dev install a module
     * @param moduleAddress module address
     * @param initData module init data
     * @param selectors function selectors that the module is allowed to call
     */
    function _installModule(address moduleAddress, bytes memory initData, bytes4[] memory selectors) internal virtual;

    /**
     * @dev uninstall a module
     * @param moduleAddress module address
     */
    function _uninstallModule(address moduleAddress) internal virtual;
}
