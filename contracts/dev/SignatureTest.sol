// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../helpers/Signatures.sol";
import "../entrypoint/Helpers.sol";

contract SignatureTest {
    using Signatures for bytes;
    using Signatures for uint256;

    constructor() {}

    function decodeSignature(
        bytes memory _bytes
    )
        public
        pure
        returns (
            SignatureData memory signatureData,
            ValidationData memory validationData
        )
    {
        signatureData = _bytes.decodeSignature();
        validationData = signatureData.validationData.decodeValidationData();
    }
}
