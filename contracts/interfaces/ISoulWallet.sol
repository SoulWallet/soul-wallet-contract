// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "./IExecutionManager.sol";
import "./IModuleManager.sol";
import "./IOwnerManager.sol";
import "./IPluginManager.sol";
import "./IFallbackManager.sol";
import "@account-abstraction/contracts/interfaces/IAccount.sol";
import "./IUpgradable.sol";

/**
 * @title SoulWallet Interface
 * @dev This interface aggregates multiple sub-interfaces to represent the functionalities of the SoulWallet
 * It encompasses account management, execution management, module management, owner management, plugin management,
 * fallback management, and upgradeability
 */
interface ISoulWallet is
    IAccount,
    IExecutionManager,
    IModuleManager,
    IOwnerManager,
    IPluginManager,
    IFallbackManager,
    IUpgradable
{}
