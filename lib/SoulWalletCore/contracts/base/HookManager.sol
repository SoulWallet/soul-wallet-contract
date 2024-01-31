// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {Authority} from "./Authority.sol";
import {IHookManager} from "../interface/IHookManager.sol";
import {IHook} from "../interface/IHook.sol";
import {IPluggable} from "../interface/IPluggable.sol";
import {IAccount, PackedUserOperation} from "../interface/IAccount.sol";
import {AccountStorage} from "../utils/AccountStorage.sol";
import {AddressLinkedList} from "../utils/AddressLinkedList.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {SIG_VALIDATION_FAILED} from "../utils/Constants.sol";
import {HookManagerSnippet} from "../snippets/HookManager.sol";

abstract contract HookManager is Authority, IHookManager, HookManagerSnippet {
    using AddressLinkedList for mapping(address => address);

    error INVALID_HOOK();
    error INVALID_HOOK_TYPE();
    error HOOK_NOT_EXISTS();
    error INVALID_HOOK_SIGNATURE();

    bytes4 private constant INTERFACE_ID_HOOK = type(IHook).interfaceId;

    /*
        Capability flags for the hook:
            0x01: preIsValidSignatureHook: execute before isValidSignature
            0x02: preUserOpValidationHook: execute before validateUserOp
     */

    uint8 internal constant PRE_IS_VALID_SIGNATURE_HOOK = 1 << 0;
    uint8 internal constant PRE_USER_OP_VALIDATION_HOOK = 1 << 1;

    /**
     * @dev Check if the hook is installed
     * @param hook The address of the hook
     */
    function isInstalledHook(address hook) external view override returns (bool) {
        return AccountStorage.layout().preUserOpValidationHook.isExist(hook)
            || AccountStorage.layout().preIsValidSignatureHook.isExist(hook);
    }

    /**
     * @dev checks whether a address is a valid hook
     * note: If you need to extend the interface, override this function
     * @param hookAddress hook address
     */
    function _isSupportsHookInterface(address hookAddress) internal view virtual override returns (bool supported) {
        bytes memory callData = abi.encodeWithSelector(IERC165.supportsInterface.selector, INTERFACE_ID_HOOK);
        assembly ("memory-safe") {
            // memorySafe: The scratch space between memory offset 0 and 64.

            let result := staticcall(gas(), hookAddress, add(callData, 0x20), mload(callData), 0x00, 0x20)
            if gt(result, 0) { supported := mload(0x00) }
        }
    }

    /**
     * @dev Install a hook
     * @param hookAddress The address of the hook
     * @param initData The init data of the hook
     * @param capabilityFlags Capability flags for the hook
     */
    function _installHook(address hookAddress, bytes memory initData, uint8 capabilityFlags)
        internal
        virtual
        override
    {
        if (_isSupportsHookInterface(hookAddress) == false) {
            revert INVALID_HOOK();
        }

        if (capabilityFlags & (PRE_USER_OP_VALIDATION_HOOK | PRE_IS_VALID_SIGNATURE_HOOK) == 0) {
            revert INVALID_HOOK_TYPE();
        }
        if (capabilityFlags & PRE_IS_VALID_SIGNATURE_HOOK == PRE_IS_VALID_SIGNATURE_HOOK) {
            AccountStorage.layout().preIsValidSignatureHook.add(hookAddress);
        }
        if (capabilityFlags & PRE_USER_OP_VALIDATION_HOOK == PRE_USER_OP_VALIDATION_HOOK) {
            AccountStorage.layout().preUserOpValidationHook.add(hookAddress);
        }

        bytes4 invalidHookSelector = INVALID_HOOK.selector;
        bytes memory callData = abi.encodeWithSelector(IPluggable.Init.selector, initData);
        assembly ("memory-safe") {
            // memorySafe: The scratch space between memory offset 0 and 64.

            let result := call(gas(), hookAddress, 0, add(callData, 0x20), mload(callData), 0x00, 0x00)
            if iszero(result) {
                mstore(0x00, invalidHookSelector)
                revert(0x00, 4)
            }
        }

        emit HookInstalled(hookAddress);
    }

    /**
     * @dev Uninstall a hook
     *      1. revert if the hook is not installed
     *      2. call hook.deInit() with 1M gas, emit HOOK_UNINSTALL_WITHERROR if the call failed
     * @param hookAddress The address of the hook
     */
    function _uninstallHook(address hookAddress) internal virtual override {
        bool removed1 = AccountStorage.layout().preIsValidSignatureHook.tryRemove(hookAddress);
        bool removed2 = AccountStorage.layout().preUserOpValidationHook.tryRemove(hookAddress);
        if (removed1 == false && removed2 == false) {
            revert HOOK_NOT_EXISTS();
        }

        (bool success,) =
            hookAddress.call{gas: 1000000 /* max to 1M gas */ }(abi.encodeWithSelector(IPluggable.DeInit.selector));

        if (success) {
            emit HookUninstalled(hookAddress);
        } else {
            emit HookUninstalledwithError(hookAddress);
        }
    }

    /**
     * @dev Uninstall a hook
     * @param hookAddress The address of the hook
     */
    function uninstallHook(address hookAddress) external virtual override {
        pluginManagementAccess();
        _uninstallHook(hookAddress);
    }

    /**
     * @dev List all installed hooks
     */
    function listHook()
        external
        view
        virtual
        override
        returns (address[] memory preIsValidSignatureHooks, address[] memory preUserOpValidationHooks)
    {
        mapping(address => address) storage preIsValidSignatureHook = AccountStorage.layout().preIsValidSignatureHook;
        preIsValidSignatureHooks =
            preIsValidSignatureHook.list(AddressLinkedList.SENTINEL_ADDRESS, preIsValidSignatureHook.size());
        mapping(address => address) storage preUserOpValidationHook = AccountStorage.layout().preUserOpValidationHook;
        preUserOpValidationHooks =
            preUserOpValidationHook.list(AddressLinkedList.SENTINEL_ADDRESS, preUserOpValidationHook.size());
    }

    /**
     * @dev Get the next hook signature
     * @param hookSignatures The hook signatures
     * @param cursor The cursor of the hook signatures
     */
    function _nextHookSignature(bytes calldata hookSignatures, uint256 cursor)
        private
        pure
        returns (address _hookAddr, uint256 _cursorFrom, uint256 _cursorEnd)
    {
        /* 
            +--------------------------------------------------------------------------------+  
            |                            multi-hookSignature                                 |  
            +--------------------------------------------------------------------------------+  
            |     hookSignature     |    hookSignature      |   ...  |    hookSignature      |
            +-----------------------+--------------------------------------------------------+  
            |     dynamic data      |     dynamic data      |   ...  |     dynamic data      |
            +--------------------------------------------------------------------------------+

            +----------------------------------------------------------------------+  
            |                                 hookSignature                        |  
            +----------------------------------------------------------------------+  
            |      Hook address    | hookSignature length  |     hookSignature     |
            +----------------------+-----------------------------------------------+  
            |        20bytes       |     4bytes(uint32)    |         bytes         |
            +----------------------------------------------------------------------+
         */
        uint256 dataLen = hookSignatures.length;

        if (dataLen > cursor) {
            assembly ("memory-safe") {
                let ptr := add(hookSignatures.offset, cursor)
                _hookAddr := shr(0x60, calldataload(ptr))
                if iszero(_hookAddr) { revert(0, 0) }
                _cursorFrom := add(cursor, 24) //20+4
                let guardSigLen := shr(0xe0, calldataload(add(ptr, 20)))
                if iszero(guardSigLen) { revert(0, 0) }
                _cursorEnd := add(_cursorFrom, guardSigLen)
            }
        }
    }

    /**
     * @dev Call preIsValidSignatureHook for all installed hooks
     * @param hash The hash of the data to be signed
     * @param hookSignatures The hook signatures
     */
    function _preIsValidSignatureHook(bytes32 hash, bytes calldata hookSignatures) internal view virtual {
        address _hookAddr;
        uint256 _cursorFrom;
        uint256 _cursorEnd;
        (_hookAddr, _cursorFrom, _cursorEnd) = _nextHookSignature(hookSignatures, _cursorEnd);

        mapping(address => address) storage preIsValidSignatureHook = AccountStorage.layout().preIsValidSignatureHook;
        address hookAddress = preIsValidSignatureHook[AddressLinkedList.SENTINEL_ADDRESS];
        while (uint160(hookAddress) > AddressLinkedList.SENTINEL_UINT) {
            bytes calldata currentHookSignature;
            if (hookAddress == _hookAddr) {
                currentHookSignature = hookSignatures[_cursorFrom:_cursorEnd];
                // next
                _hookAddr = address(0);
                if (_cursorEnd > 0) {
                    (_hookAddr, _cursorFrom, _cursorEnd) = _nextHookSignature(hookSignatures, _cursorEnd);
                }
            } else {
                currentHookSignature = hookSignatures[0:0];
            }

            bytes memory callData =
                abi.encodeWithSelector(IHook.preIsValidSignatureHook.selector, hash, currentHookSignature);
            assembly ("memory-safe") {
                // memorySafe: The scratch space between memory offset 0 and 64.

                let result := staticcall(gas(), hookAddress, add(callData, 0x20), mload(callData), 0x00, 0x00)
                if iszero(result) {
                    /*
                        Warning!!!
                            This function uses `return` to terminate the execution of the entire contract.
                            If any `Hook` fails, this function will stop the contract's execution and
                            return `bytes4(0)`, skipping all the subsequent unexecuted code.
                     */
                    mstore(0x00, 0x00000000)
                    return(0x00, 0x20)
                }
            }

            hookAddress = preIsValidSignatureHook[hookAddress];
        }

        if (_hookAddr != address(0)) {
            revert INVALID_HOOK_SIGNATURE();
        }
    }

    /**
     * @dev Call preUserOpValidationHook for all installed hooks
     *
     * Warning!!!
     *  This function uses `return` to terminate the execution of the entire contract.
     *  If any `Hook` fails, this function will stop the contract's execution and
     *  return `SIG_VALIDATION_FAILED`, skipping all the subsequent unexecuted code.
     *
     *
     *
     * @param userOp The UserOperation
     * @param userOpHash The hash of the UserOperation
     * @param missingAccountFunds The missing account funds
     * @param hookSignatures The hook signatures
     */
    function _preUserOpValidationHook(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds,
        bytes calldata hookSignatures
    ) internal virtual {
        address _hookAddr;
        uint256 _cursorFrom;
        uint256 _cursorEnd;
        (_hookAddr, _cursorFrom, _cursorEnd) = _nextHookSignature(hookSignatures, _cursorEnd);

        mapping(address => address) storage preUserOpValidationHook = AccountStorage.layout().preUserOpValidationHook;
        address hookAddress = preUserOpValidationHook[AddressLinkedList.SENTINEL_ADDRESS];
        while (uint160(hookAddress) > AddressLinkedList.SENTINEL_UINT) {
            bytes calldata currentHookSignature;
            if (hookAddress == _hookAddr) {
                currentHookSignature = hookSignatures[_cursorFrom:_cursorEnd];
                // next
                _hookAddr = address(0);
                if (_cursorEnd > 0) {
                    (_hookAddr, _cursorFrom, _cursorEnd) = _nextHookSignature(hookSignatures, _cursorEnd);
                }
            } else {
                currentHookSignature = hookSignatures[0:0];
            }

            bytes memory callData = abi.encodeWithSelector(
                IHook.preUserOpValidationHook.selector, userOp, userOpHash, missingAccountFunds, currentHookSignature
            );
            assembly ("memory-safe") {
                // memorySafe: The scratch space between memory offset 0 and 64.

                let result := call(gas(), hookAddress, 0, add(callData, 0x20), mload(callData), 0x00, 0x00)
                if iszero(result) {
                    /*
                        Warning!!!
                            This function uses `return` to terminate the execution of the entire contract.
                            If any `Hook` fails, this function will stop the contract's execution and
                            return `SIG_VALIDATION_FAILED`, skipping all the subsequent unexecuted code.
                     */
                    mstore(0x00, SIG_VALIDATION_FAILED)
                    return(0x00, 0x20)
                }
            }

            hookAddress = preUserOpValidationHook[hookAddress];
        }
        if (_hookAddr != address(0)) {
            revert INVALID_HOOK_SIGNATURE();
        }
    }
}
