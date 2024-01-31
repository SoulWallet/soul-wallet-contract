// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {PackedUserOperation} from "../contracts/interface/IAccount.sol";
import {SoulWalletCore} from "../contracts/SoulWalletCore.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {OwnerManagerSnippet} from "../contracts/snippets/OwnerManager.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "../contracts/utils/Constants.sol";
import {ModuleInstaller} from "../contracts/extensions/ModuleInstaller.sol";
import {HookInstaller} from "../contracts/extensions/HookInstaller.sol";
import {ValidatorInstaller} from "../contracts/extensions/ValidatorInstaller.sol";
import {ValidatorManager} from "../contracts/base/ValidatorManager.sol";
import {ValidatorManagerSnippet} from "../contracts/snippets/ValidatorManager.sol";

abstract contract BuildinEOAValidator is OwnerManagerSnippet {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // Magic value indicating a valid signature for ERC-1271 contracts
    bytes4 private constant __MAGICVALUE = bytes4(keccak256("isValidSignature(bytes32,bytes)"));

    function __packHash(bytes32 hash) internal view returns (bytes32) {
        return keccak256(abi.encode(hash, address(this), block.chainid));
    }

    function __validateSignature(bytes32 hash, bytes calldata validatorSignature)
        internal
        view
        returns (bytes4 magicValue)
    {
        if (validatorSignature.length != 65) {
            return bytes4(0);
        }

        bytes32 r = bytes32(validatorSignature[0:0x20]);
        bytes32 s = bytes32(validatorSignature[0x20:0x40]);
        uint8 v = uint8(bytes1(validatorSignature[0x40:0x41]));

        (address recoveredAddr, ECDSA.RecoverError error,) =
            ECDSA.tryRecover(__packHash(hash).toEthSignedMessageHash(), v, r, s);
        if (error != ECDSA.RecoverError.NoError) {
            return bytes4(0);
        }
        return _isOwner(bytes32(uint256(uint160(recoveredAddr)))) ? __MAGICVALUE : bytes4(0);
    }

    function __validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        bytes calldata validatorSignature
    ) internal view returns (uint256 validationData) {
        (userOp);

        if (validatorSignature.length != 65) {
            return SIG_VALIDATION_FAILED;
        }
        bytes32 r = bytes32(validatorSignature[0x00:0x20]);
        bytes32 s = bytes32(validatorSignature[0x20:0x40]);
        uint8 v = uint8(bytes1(validatorSignature[0x40:0x41]));

        (address recoveredAddr, ECDSA.RecoverError error,) =
            ECDSA.tryRecover(__packHash(userOpHash).toEthSignedMessageHash(), v, r, s);
        if (error != ECDSA.RecoverError.NoError) {
            return SIG_VALIDATION_FAILED;
        }

        return _isOwner(bytes32(uint256(uint160(recoveredAddr)))) ? SIG_VALIDATION_SUCCESS : SIG_VALIDATION_FAILED;
    }
}

contract ModularAccountWithBuildinEOAValidator is
    ValidatorInstaller,
    HookInstaller,
    ModuleInstaller,
    SoulWalletCore,
    BuildinEOAValidator
{
    uint256 private _initialized;

    modifier initializer() {
        require(_initialized == 0);
        _initialized = 1;
        _;
    }

    constructor(address _entryPoint) SoulWalletCore(_entryPoint) initializer {}

    function initialize(bytes32 owner) external initializer {
        _addOwner(owner);
    }

    /**
     * @dev EIP-1271
     * @param hash hash of the data to be signed
     * @param validator validator address
     * @param validatorSignature Signature byte array associated with _data
     * @return magicValue Magic value 0x1626ba7e if the validator is registered and signature is valid
     */
    function _isValidSignature(bytes32 hash, address validator, bytes calldata validatorSignature)
        internal
        view
        override(ValidatorManagerSnippet, ValidatorManager)
        returns (bytes4 magicValue)
    {
        if (validator == address(0)) {
            return __validateSignature(hash, validatorSignature);
        }
        return super._isValidSignature(hash, validator, validatorSignature);
    }

    /**
     * @dev validate UserOperation
     * @param userOp UserOperation
     * @param userOpHash UserOperation hash
     * @param validator validator address
     * @param validatorSignature validator signature
     * @return validationData refer to https://github.com/eth-infinitism/account-abstraction/blob/v0.6.0/contracts/interfaces/IAccount.sol#L24-L30
     */
    function _validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        address validator,
        bytes calldata validatorSignature
    ) internal override(ValidatorManagerSnippet, ValidatorManager) returns (uint256 validationData) {
        if (validator == address(0)) {
            return __validateUserOp(userOp, userOpHash, validatorSignature);
        }
        return super._validateUserOp(userOp, userOpHash, validator, validatorSignature);
    }
}
