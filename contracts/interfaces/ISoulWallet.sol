// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISoulWalletHookManager} from "../interfaces/ISoulWalletHookManager.sol";
import {ISoulWalletModuleManager} from "../interfaces/ISoulWalletModuleManager.sol";
import {ISoulWalletOwnerManager} from "../interfaces/ISoulWalletOwnerManager.sol";
import {ISoulWalletOwnerManager} from "../interfaces/ISoulWalletOwnerManager.sol";
import {IUpgradable} from "../interfaces/IUpgradable.sol";
import {IStandardExecutor} from "@soulwallet-core/contracts/interface/IStandardExecutor.sol";

interface ISoulWallet is
    ISoulWalletHookManager,
    ISoulWalletModuleManager,
    ISoulWalletOwnerManager,
    IStandardExecutor,
    IUpgradable
{
    function initialize(
        bytes32[] calldata owners,
        address defalutCallbackHandler,
        bytes[] calldata modules,
        bytes[] calldata hooks
    ) external;
}
