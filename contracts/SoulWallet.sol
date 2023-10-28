// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@account-abstraction/contracts/core/BaseAccount.sol";
import "./interfaces/ISoulWallet.sol";
import "./base/EntryPointManager.sol";
import "./base/ExecutionManager.sol";
import "./base/PluginManager.sol";
import "./base/ModuleManager.sol";
import "./base/OwnerManager.sol";
import "./helper/SignatureValidator.sol";
import "./handler/ERC1271Handler.sol";
import "./base/FallbackManager.sol";
import "./base/UpgradeManager.sol";
import "./base/ValidatorManager.sol";

/// @title SoulWallet
/// @author  SoulWallet team
/// @notice logic contract of SoulWallet
/// @dev Draft contract - may be subject to changes
contract SoulWallet is
    Initializable,
    ISoulWallet,
    BaseAccount,
    EntryPointManager,
    OwnerManager,
    SignatureValidator,
    PluginManager,
    ModuleManager,
    UpgradeManager,
    ExecutionManager,
    FallbackManager,
    ERC1271Handler,
    ValidatorManager
{
    /// @notice Creates a new SoulWallet instance
    /// @param _EntryPoint Address of the entry point
    /// @param _validator Address of the validator
    constructor(IEntryPoint _EntryPoint, IValidator _validator)
        EntryPointManager(_EntryPoint)
        ValidatorManager(_validator)
    {
        _disableInitializers();
    }

    /// @notice Initializes the SoulWallet with given parameters
    /// @param owners List of owner addresses (passkey public key hash or eoa address)
    /// @param defalutCallbackHandler Default callback handler address
    /// @param modules List of module data
    /// @param plugins List of plugin data
    function initialize(
        bytes32[] calldata owners,
        address defalutCallbackHandler,
        bytes[] calldata modules,
        bytes[] calldata plugins
    ) external initializer {
        _addOwners(owners);
        _setFallbackHandler(defalutCallbackHandler);
        for (uint256 i = 0; i < modules.length;) {
            _addModule(modules[i]);
            unchecked {
                i++;
            }
        }
        for (uint256 i = 0; i < plugins.length;) {
            _addPlugin(plugins[i]);
            unchecked {
                i++;
            }
        }
    }

    /// @notice Gets the address of the entry point
    /// @return IEntryPoint Address of the entry point
    function entryPoint() public view override(BaseAccount) returns (IEntryPoint) {
        return EntryPointManager._entryPoint();
    }

    /// @notice Validates the user's signature
    /// @param userOp User operation details
    /// @param userOpHash Hash of the user operation
    /// @return validationData Data related to validation process
    function _validateSignature(UserOperation calldata userOp, bytes32 userOpHash)
        internal
        virtual
        override
        returns (uint256 validationData)
    {
        bool sigValid;
        bytes calldata guardHookInputData;
        (validationData, sigValid, guardHookInputData) = _isValidUserOp(userOpHash, userOp.signature);

        /* 
          Why using the current "non-gas-optimized" approach instead of using 
          `sigValid = sigValid && guardHook(userOp, userOpHash, guardHookInputData);` :
          
          When data is executed on the blockchain, if `sigValid = true`, the gas cost remains consistent.
          However, the benefits of using this approach are quite apparent:
          By using "semi-valid" signatures off-chain to estimate gas fee (sigValid will always be false), 
          the estimated fee can include a portion of the execution cost of `guardHook`. 
         */
        bool guardHookResult = guardHook(userOp, userOpHash, guardHookInputData);

        // equivalence code: `(sigFailed ? 1 : 0) | (uint256(validUntil) << 160) | (uint256(validAfter) << (160 + 48))`
        // validUntil and validAfter is already packed in signatureData.validationData,
        // and aggregator is address(0), so we just need to add sigFailed flag.
        validationData = validationData | ((sigValid && guardHookResult) ? 0 : SIG_VALIDATION_FAILED);
    }

    /// @notice Upgrades the contract to a new implementation
    /// @param newImplementation Address of the new implementation
    /// @dev Can only be called from an external module for security reasons
    function upgradeTo(address newImplementation) external onlyModule {
        UpgradeManager._upgradeTo(newImplementation);
    }

    /// @notice Handles the upgrade from an old implementation
    /// @param oldImplementation Address of the old implementation
    function upgradeFrom(address oldImplementation) external pure override {
        (oldImplementation);
        revert Errors.NOT_IMPLEMENTED(); //Initial version no need data migration
    }
}
