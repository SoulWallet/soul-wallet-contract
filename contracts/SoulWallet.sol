// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../account-abstraction/contracts/core/BaseAccount.sol";
import "../account-abstraction/contracts/samples/callback/TokenCallbackHandler.sol";
import "./interfaces/ISoulWallet.sol";
import "./libraries/AccountStorage.sol";
import "./base/EntryPointBase.sol";
import "./base/DepositManager.sol";
import "./base/ExecutionManager.sol";
import "./base/ImmediateOperand.sol";
import "./base/GuardianManager.sol";
import "./libraries/SignatureValidator.sol";

// Draft
contract SoulWallet is
    Initializable,
    BaseAccount,
    ISoulWallet,
    TokenCallbackHandler,
    DepositManager,
    ExecutionManager,
    ImmediateOperand,
    GuardianManager
{
    using AccountStorage for AccountStorage.Layout;

    constructor(
        IEntryPoint anEntryPoint,
        uint64 safeLockPeriod,
        ITrustedModuleManager trustedModuleManager,
        address anOwner
    ) public ImmediateOperand(anEntryPoint) ExecutionManager(safeLockPeriod, trustedModuleManager) {
        AccountStorage.Layout storage layout = AccountStorage.layout();
        layout.owner = anOwner;

        _disableInitializers();
    }

    function entryPoint()
        public
        view
        override(BaseAccount, EntryPointBase)
        returns (IEntryPoint)
    {
        return ImmediateOperand._getEntryPoint();
    }

    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) internal virtual override returns (uint256 validationData) {
        return SignatureValidator.isValid(userOp, userOpHash);
    }

    fallback() external payable {
        super._beforeFallback();
    }


}
