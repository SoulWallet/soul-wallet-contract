// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "../interfaces/IModule.sol";
import "../interfaces/ISoulWallet.sol";
import "../interfaces/IModuleManager.sol";

/**
 * @title BaseModule
 * @notice An abstract base contract that provides a foundation for other modules.
 * It ensures the initialization, de-initialization, and proper authorization of modules.
 */
abstract contract BaseModule is IModule {
    event ModuleInit(address indexed wallet);
    event ModuleDeInit(address indexed wallet);
    /**
     * @notice Checks if the module is initialized for a particular wallet.
     * @param wallet Address of the wallet.
     * @return True if the module is initialized, false otherwise.
     */

    function inited(address wallet) internal view virtual returns (bool);
    /**
     * @notice Initialization logic for the module.
     * @param data Initialization data for the module.
     */
    function _init(bytes calldata data) internal virtual;
    /**
     * @notice De-initialization logic for the module.
     */
    function _deInit() internal virtual;
    /**
     * @notice Helper function to get the sender of the transaction.
     * @return Address of the transaction sender.
     */

    function sender() internal view returns (address) {
        return msg.sender;
    }
    /**
     * @notice Initializes the module for a wallet.
     * @param data Initialization data for the module.
     */

    function walletInit(bytes calldata data) external {
        address _sender = sender();
        if (!inited(_sender)) {
            if (!ISoulWallet(_sender).isAuthorizedModule(address(this))) {
                revert("not authorized module");
            }
            _init(data);
            emit ModuleInit(_sender);
        }
    }
    /**
     * @notice De-initializes the module for a wallet.
     */

    function walletDeInit() external {
        address _sender = sender();
        if (inited(_sender)) {
            if (ISoulWallet(_sender).isAuthorizedModule(address(this))) {
                revert("authorized module");
            }
            _deInit();
            emit ModuleDeInit(_sender);
        }
    }
    /**
     * @notice Verifies if the module supports a specific interface.
     * @param interfaceId ID of the interface to be checked.
     * @return True if the module supports the given interface, false otherwise.
     */

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IModule).interfaceId;
    }
}
