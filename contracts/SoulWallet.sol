// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../account-abstraction/contracts/core/BaseAccount.sol";
import "./interfaces/ISoulWallet.sol";
import "./base/DepositManager.sol";
import "./base/EntryPointManager.sol";
import "./base/ExecutionManager.sol";
import "./base/ModuleManager.sol";
import "./base/OwnerManager.sol";
import "./helper/SignatureValidator.sol";
import "./handler/ERC1271Handler.sol";
import "./base/FallbackManager.sol";
import "./interfaces/IModule.sol";

// Draft
contract SoulWallet is
    Initializable,
    ISoulWallet,
    BaseAccount,
    EntryPointManager,
    OwnerManager,
    SignatureValidator,
    ModuleManager,
    DepositManager,
    ExecutionManager,
    FallbackManager,
    ERC1271Handler
{
    constructor(
        IEntryPoint anEntryPoint,
        address defaultModuleManager
    ) EntryPointManager(anEntryPoint) ModuleManager(defaultModuleManager) {
        _disableInitializers();
    }

    function initialize(
        address anOwner,
        address defalutCallbackHandler,
        Module[] calldata modules,
        Plugin[] calldata plugins
    ) public initializer {
        addOwner(anOwner);
        if (defalutCallbackHandler != address(0)) internalSetFallbackHandler(defalutCallbackHandler);

        for (uint256 i = 0; i < modules.length; i++) {
            addModule(modules[i]);
        }
        for (uint256 i = 0; i < plugins.length; i++) {
            addPlugin(plugins[i]);
        }

    }

    function entryPoint()
        public
        view
        override(BaseAccount)
        returns (IEntryPoint)
    {
        return EntryPointManager._entryPoint();
    }

    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) internal virtual override returns (uint256 validationData) {
         bool sigValid;
        (validationData, sigValid) = isValidUserOp(userOpHash, userOp.signature);
        
        if(sigValid){
            sigValid = guardHook(userOp, userOpHash);
        }

        // equivalence code: `(sigFailed ? 1 : 0) | (uint256(validUntil) << 160) | (uint256(validAfter) << (160 + 48))`
        // validUntil and validAfter is already packed in signatureData.validationData,
        // and aggregator is address(0), so we just need to add sigFailed flag.
        validationData = validationData | (sigValid ? 0 : SIG_VALIDATION_FAILED);
        
    }
}
