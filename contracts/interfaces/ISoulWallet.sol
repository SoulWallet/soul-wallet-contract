// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

// import "../../account-abstraction/contracts/interfaces/IAccount.sol";
import "./IDepositManager.sol";
import "./IExecutionManager.sol";
import "./IModuleManager.sol";
import "./IOwnerManager.sol";
import "./IPluginManager.sol";
import "./IFallbackManager.sol";

interface ISoulWallet is
    // IAccount,
    IDepositManager,
    IExecutionManager,
    IModuleManager,
    IOwnerManager,
    IPluginManager,
    IFallbackManager
{}
