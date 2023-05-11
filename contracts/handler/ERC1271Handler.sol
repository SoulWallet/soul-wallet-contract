// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "../helper/SignatureValidator.sol";
import "../../account-abstraction/contracts/core/Helpers.sol";

abstract contract ERC1271Handler is IERC1271, SignatureValidator {
    // bytes4(keccak256("isValidSignature(bytes32,bytes)")
    bytes4 internal constant MAGICVALUE = 0x1626ba7e;
    bytes4 internal constant InvalidID = 0xffffffff;
    bytes4 internal constant InvalidTimeRange = 0xfffffffe;

    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view override returns (bytes4 magicValue) {
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
}
