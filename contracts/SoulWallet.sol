// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

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

// Draft
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
    ERC1271Handler
{
    constructor(IEntryPoint _EntryPoint) EntryPointManager(_EntryPoint) {
        _disableInitializers();
    }

    function initialize(
        address anOwner,
        address defalutCallbackHandler,
        bytes[] calldata modules,
        bytes[] calldata plugins
    ) external initializer {
        _addOwner(anOwner);
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

    function entryPoint() public view override(BaseAccount) returns (IEntryPoint) {
        return EntryPointManager._entryPoint();
    }

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

    function upgradeTo(address newImplementation) external onlyModule {
        UpgradeManager._upgradeTo(newImplementation);
    }

    function upgradeFrom(address oldImplementation) external pure override {
        (oldImplementation);
        revert Errors.NOT_IMPLEMENTED(); //Initial version no need data migration
    }
}
