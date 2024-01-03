// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UserOperation} from "../interface/IAccount.sol";
import {IPluggable} from "./IPluggable.sol";

interface IValidator is IPluggable {
    /*
        NOTE: Any implementation must ensure that the `validatorSignature` exactly matches your expectations, 
              otherwise, you will face security risks.
              For example: 
                if you do not require any `validatorSignature`, make sure your implementation included the following code:
                `require(validatorSignature.length == 0)`
     */

    /**
     * @dev EIP-1271 Should return whether the signature provided is valid for the provided data
     * @param sender    Address of the message sender
     * @param hash      Hash of the data to be signed
     * @param validatorSignature Signature byte array associated with _data
     */
    function validateSignature(address sender, bytes32 hash, bytes memory validatorSignature)
        external
        view
        returns (bytes4 magicValue);

    /**
     * @dev EIP-4337 validate userOperation
     * NOTE: Do not rely on userOperation.signature, which may be empty in some versions of the implementation, see: contract/utils/CalldataPack.sol
     * @param userOp the operation that is about to be executed.
     * @param userOpHash hash of the user's request data. can be used as the basis for signature.
     * @param validatorSignature Signature
     * @return validationData packaged ValidationData structure. use `_packValidationData` and `_unpackValidationData` to encode and decode
     *      <20-byte> sigAuthorizer - 0 for valid signature, 1 to mark signature failure,
     *         otherwise, an address of an "authorizer" contract.
     *      <6-byte> validUntil - last timestamp this operation is valid. 0 for "indefinite"
     *      <6-byte> validAfter - first timestamp this operation is valid
     *      If an account doesn't use time-range, it is enough to return SIG_VALIDATION_FAILED value (1) for signature failure.
     *      Note that the validation code cannot use block.timestamp (or block.number) directly.
     */
    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, bytes calldata validatorSignature)
        external
        returns (uint256 validationData);
}
