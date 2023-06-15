// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../helper/SignatureValidator.sol";
import "@account-abstraction/contracts/core/Helpers.sol";
import "../interfaces/IERC1271Handler.sol";
import "../authority/Authority.sol";
import "../libraries/AccountStorage.sol";

abstract contract ERC1271Handler is Authority, IERC1271Handler, SignatureValidator {
    // bytes4(keccak256("isValidSignature(bytes32,bytes)")
    bytes4 internal constant MAGICVALUE = 0x1626ba7e;
    bytes4 internal constant INVALID_ID = 0xffffffff;
    bytes4 internal constant INVALID_TIME_RANGE = 0xfffffffe;

    function _approvedHashes() private view returns (mapping(bytes32 => uint256) storage) {
        return AccountStorage.layout().approvedHashes;
    }

    function isValidSignature(bytes32 hash, bytes calldata signature)
        external
        view
        override
        returns (bytes4 magicValue)
    {
        if (signature.length > 0) {
            (uint256 _validationData, bool sigValid) = _isValidateSignature(hash, signature);
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
        uint256 status = approvedHashes[hash];
        if (status == 1) {
            // approved
            return MAGICVALUE;
        } else {
            return INVALID_ID;
        }
    }

    function approveHash(bytes32 hash) external override onlySelfOrModule {
        mapping(bytes32 => uint256) storage approvedHashes = _approvedHashes();
        if (approvedHashes[hash] == 1) {
            revert Errors.HASH_ALREADY_APPROVED();
        }
        approvedHashes[hash] = 1;
        emit ApproveHash(hash);
    }

    function rejectHash(bytes32 hash) external override onlySelfOrModule {
        mapping(bytes32 => uint256) storage approvedHashes = _approvedHashes();
        if (approvedHashes[hash] == 0) {
            revert Errors.HASH_ALREADY_REJECTED();
        }
        approvedHashes[hash] = 0;
        emit RejectHash(hash);
    }
}
