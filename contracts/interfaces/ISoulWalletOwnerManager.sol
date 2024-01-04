// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {IOwnerManager} from "@soulwallet-core/contracts/interface/IOwnerManager.sol";
interface ISoulWalletOwnerManager is IOwnerManager {
    function addOwners(bytes32[] calldata owners) external;
    function resetOwners(bytes32[] calldata newOwners) external;
}
