// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../helper/SignatureValidator.sol";
import "../../account-abstraction/contracts/core/Helpers.sol";
import "../interfaces/IERC1271Handler.sol";
import "../authority/Authority.sol";

import "../libraries/AccountStorage.sol";

abstract contract ERC1271Handler is
    Authority,
    IERC1271Handler,
    SignatureValidator
{
    // bytes4(keccak256("isValidSignature(bytes32,bytes)")
    bytes4 internal constant MAGICVALUE = 0x1626ba7e;
    bytes4 internal constant InvalidID = 0xffffffff;
    bytes4 internal constant InvalidTimeRange = 0xfffffffe;

    function _hashStatusMap()
        private
        view
        returns (mapping(bytes32 => uint256) storage)
    {
        return AccountStorage.layout().hashStatus;
    }

    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view override returns (bytes4 magicValue) {
        if (signature.length == 0) {
            (uint256 _validationData, bool sigValid) = isValidateSignature(
                hash,
                signature
            );
            if (!sigValid) {
                return InvalidID;
            }
            if (_validationData > 0) {
                ValidationData memory validationData = _parseValidationData(
                    _validationData
                );
                bool outOfTimeRange = (block.timestamp >
                    validationData.validUntil) ||
                    (block.timestamp < validationData.validAfter);
                if (outOfTimeRange) {
                    return InvalidTimeRange;
                }
            }
            return MAGICVALUE;
        }

        mapping(bytes32 => uint256) storage hashStatusMap = _hashStatusMap();
        uint256 status = hashStatusMap[hash];
        if (status == 1) {
            // approved
            return MAGICVALUE;
        } else {
            return InvalidID;
        }
    }

    function approveHash(bytes32 hash) external override onlyEntryPointOrSelf {
        mapping(bytes32 => uint256) storage hashStatusMap = _hashStatusMap();
        require(
            hashStatusMap[hash] != 1,
            "ERC1271Handler: hash already approved"
        );
        hashStatusMap[hash] = 1;
        emit ApproveHash(hash);
    }

    function rejectHash(bytes32 hash) external override onlyEntryPointOrSelf {
        mapping(bytes32 => uint256) storage hashStatusMap = _hashStatusMap();
        require(
            hashStatusMap[hash] != 0,
            "ERC1271Handler: hash already rejected"
        );
        hashStatusMap[hash] = 0;
        emit RejectHash(hash);
    }
}
