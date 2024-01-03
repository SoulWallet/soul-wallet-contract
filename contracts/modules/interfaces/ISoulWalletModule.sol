// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;
import {IModule} from "@soulwallet-core/contracts/interface/IModule.sol";

interface ISoulWalletModule is IModule {
    function requiredFunctions() external pure returns (bytes4[] memory);
}
