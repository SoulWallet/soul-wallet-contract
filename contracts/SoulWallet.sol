// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../account-abstraction/contracts/core/BaseAccount.sol";
import "../account-abstraction/contracts/samples/callback/TokenCallbackHandler.sol";
import "./interfaces/ISoulWallet.sol";
import "./base/DepositManager.sol";
import "./base/EntryPointManager.sol";
import "./base/ExecutionManager.sol";
import "./base/GuardianManager.sol";
import "./base/ModuleManager.sol";
import "./base/OwnerManager.sol";
import "./base/PluginManager.sol";
import "./libraries/SignatureValidator.sol";
import "./handler/ERC1271Handler.sol";
import "./base/FallbackManager.sol";

// Draft
contract SoulWallet is
    Initializable,
    ISoulWallet,
    BaseAccount,
    ModuleManager,
    PluginManager,
    DepositManager,
    EntryPointManager,
    ExecutionManager,
    GuardianManager,
    OwnerManager,
    ERC1271Handler,
    FallbackManager,
    TokenCallbackHandler
{
    constructor(
        IEntryPoint anEntryPoint,
        address aSafePluginManager,
        address aSafeModuleManager,
        address aGuardianManager
    )
        EntryPointManager(anEntryPoint)
        ModuleManager(aSafeModuleManager)
        PluginManager(aSafePluginManager)
        GuardianManager(aGuardianManager)
    {}

    function initialize(address anOwner) public initializer {
        addOwner(anOwner);

        _disableInitializers();
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
        return SignatureValidator.isValid(userOp, userOpHash);
    }

}
