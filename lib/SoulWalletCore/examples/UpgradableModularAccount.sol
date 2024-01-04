// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BasicModularAccount} from "./BasicModularAccount.sol";
import {ModuleInstaller} from "../contracts/extensions/ModuleInstaller.sol";
import {HookInstaller} from "../contracts/extensions/HookInstaller.sol";
import {ValidatorInstaller} from "../contracts/extensions/ValidatorInstaller.sol";

contract UpgradableModularAccount is BasicModularAccount, ValidatorInstaller, HookInstaller, ModuleInstaller {
    //
    event Upgraded(address indexed oldImplementation, address indexed newImplementation);

    /**
     * @dev Storage slot with the address of the current implementation:
     *  https://github.com/SoulWallet/SoulWalletCore/blob/main/test/dev/SoulWalletProxy.sol
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1
     */
    bytes32 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function upgradeTo(address newImplementation) external {
        _onlySelfOrModule();

        bool isContract;
        assembly ("memory-safe") {
            isContract := gt(extcodesize(newImplementation), 0)
        }
        if (!isContract) {
            revert("new implementation is not a contract");
        }
        address oldImplementation;
        assembly ("memory-safe") {
            oldImplementation := and(sload(_IMPLEMENTATION_SLOT), 0xffffffffffffffffffffffffffffffffffffffff)
        }
        if (oldImplementation == newImplementation) {
            revert("new implementation is the same as old one");
        }
        assembly ("memory-safe") {
            sstore(_IMPLEMENTATION_SLOT, newImplementation)
        }

        emit Upgraded(oldImplementation, newImplementation);
    }
}
