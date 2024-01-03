// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IHookManager} from "@soulwallet-core/contracts/interface/IHookManager.sol";

interface ISoulWalletHookManager is IHookManager {
    function installHook(bytes calldata hookAndData, uint8 capabilityFlags) external;
}
