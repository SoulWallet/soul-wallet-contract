// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IValidator} from "../interface/IValidator.sol";
import {UserOperation} from "../interface/IAccount.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IOwnable} from "../interface/IOwnable.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "../utils/Constants.sol";

contract EOAValidator is IValidator {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // Magic value indicating a valid signature for ERC-1271 contracts
    bytes4 private constant MAGICVALUE = bytes4(keccak256("isValidSignature(bytes32,bytes)"));

    bytes4 private constant INTERFACE_ID_VALIDATOR = type(IValidator).interfaceId;

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == INTERFACE_ID_VALIDATOR;
    }

    function Init(bytes calldata data) external pure override {}

    function DeInit() external pure override {}

    function _packHash(bytes32 hash) internal view returns (bytes32) {
        /*
            must pack the hash with the chainId and the address of the wallet contract to prevent replay attacks
         */
        return keccak256(abi.encode(hash, msg.sender, block.chainid));
    }

    function _isOwner(address addr) private view returns (bool isOwner) {
        bytes memory callData = abi.encodeWithSelector(IOwnable.isOwner.selector, bytes32(uint256(uint160(addr))));
        assembly ("memory-safe") {
            // memorySafe: The scratch space between memory offset 0 and 64.

            // IOwnable(msg.sender).isOwner(bytes32(uint256(uint160(addr)))) returns (bool result)
            let result := staticcall(gas(), caller(), add(callData, 0x20), mload(callData), 0x00, 0x20)
            if result { isOwner := mload(0x00) }
        }
    }

    function validateSignature(address sender, bytes32 hash, bytes calldata validatorSignature)
        external
        view
        override
        returns (bytes4 magicValue)
    {
        (sender);
        if (validatorSignature.length != 65) {
            return bytes4(0);
        }
        bytes32 r = bytes32(validatorSignature[0:0x20]);
        bytes32 s = bytes32(validatorSignature[0x20:0x40]);
        uint8 v = uint8(bytes1(validatorSignature[0x40:0x41]));

        (address recoveredAddr, ECDSA.RecoverError error,) =
            ECDSA.tryRecover(_packHash(hash).toEthSignedMessageHash(), v, r, s);
        if (error != ECDSA.RecoverError.NoError) {
            return bytes4(0);
        }
        return _isOwner(recoveredAddr) ? MAGICVALUE : bytes4(0);
    }

    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, bytes calldata validatorSignature)
        external
        view
        override
        returns (uint256 validationData)
    {
        (userOp);

        if (validatorSignature.length != 65) {
            return SIG_VALIDATION_FAILED;
        }
        bytes32 r = bytes32(validatorSignature[0x00:0x20]);
        bytes32 s = bytes32(validatorSignature[0x20:0x40]);
        uint8 v = uint8(bytes1(validatorSignature[0x40:0x41]));
        (address recoveredAddr, ECDSA.RecoverError error,) =
            ECDSA.tryRecover(_packHash(userOpHash).toEthSignedMessageHash(), v, r, s);
        if (error != ECDSA.RecoverError.NoError) {
            return SIG_VALIDATION_FAILED;
        }
        return _isOwner(recoveredAddr) ? SIG_VALIDATION_SUCCESS : SIG_VALIDATION_FAILED;
    }
}
