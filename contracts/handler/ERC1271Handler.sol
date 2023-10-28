// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "../helper/SignatureValidator.sol";
import "@account-abstraction/contracts/core/Helpers.sol";
import "../interfaces/IERC1271Handler.sol";
import "../authority/Authority.sol";
import "../libraries/AccountStorage.sol";

/**
 * @title ERC1271Handler
 * @dev This contract provides functionality to handle ERC1271 signature validations
 */
abstract contract ERC1271Handler is Authority, IERC1271Handler, SignatureValidator {
    // Magic value indicating a valid signature for ERC-1271 contracts
    // bytes4(keccak256("isValidSignature(bytes32,bytes)")
    bytes4 internal constant MAGICVALUE = 0x1626ba7e;
    // Constants indicating different invalid states
    bytes4 internal constant INVALID_ID = 0xffffffff;
    bytes4 internal constant INVALID_TIME_RANGE = 0xfffffffe;
    /**
     * @dev Provides access to the mapping of approved hashes from the AccountStorage
     * @return The mapping of approved hashes
     */

    function _approvedHashes() private view returns (mapping(bytes32 => uint256) storage) {
        return AccountStorage.layout().approvedHashes;
    }
    /**
     * @dev Checks if a given signature is valid for the provided hash
     * @param rawHash The raw hash to check the signature against
     * @param signature The provided signature
     * @return magicValue A bytes4 magic value indicating the result of the signature check
     */

    function isValidSignature(bytes32 rawHash, bytes calldata signature)
        external
        view
        override
        returns (bytes4 magicValue)
    {
        bytes32 datahash = _encodeRawHash(rawHash);
        if (signature.length > 0) {
            (uint256 _validationData, bool sigValid) = _isValidate1271Signature(datahash, signature);
            if (!sigValid) {
                return INVALID_ID;
            }
            if (_validationData > 0) {
                ValidationData memory validationData = _parseValidationData(_validationData);
                bool outOfTimeRange =
                    (block.timestamp > validationData.validUntil) || (block.timestamp < validationData.validAfter);
                if (outOfTimeRange) {
                    return INVALID_TIME_RANGE;
                }
            }
            return MAGICVALUE;
        }

        mapping(bytes32 => uint256) storage approvedHashes = _approvedHashes();
        uint256 status = approvedHashes[datahash];
        if (status == 1) {
            // approved
            return MAGICVALUE;
        } else {
            return INVALID_ID;
        }
    }
    /**
     * @dev Approves a given hash
     * @param hash The hash to be approved
     */

    function approveHash(bytes32 hash) external override onlySelfOrModule {
        mapping(bytes32 => uint256) storage approvedHashes = _approvedHashes();
        if (approvedHashes[hash] == 1) {
            revert Errors.HASH_ALREADY_APPROVED();
        }
        approvedHashes[hash] = 1;
        emit ApproveHash(hash);
    }
    /**
     * @dev Rejects a given hash
     * @param hash The hash to be rejected
     */

    function rejectHash(bytes32 hash) external override onlySelfOrModule {
        mapping(bytes32 => uint256) storage approvedHashes = _approvedHashes();
        if (approvedHashes[hash] == 0) {
            revert Errors.HASH_ALREADY_REJECTED();
        }
        approvedHashes[hash] = 0;
        emit RejectHash(hash);
    }
}
