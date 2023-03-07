// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../helpers/Signatures.sol";
import "../entrypoint/Helpers.sol";
import "hardhat/console.sol";

contract SignatureHelperTest {
    using Signatures for bytes;
    using Signatures for uint256;

    constructor() {}

    function decodeSignature(
        bytes memory _bytes
    )
        public
        view
        returns (
            SignatureData memory signatureData,
            ValidationData memory validationData
        )
    {
        signatureData = _bytes.decodeSignature();
        validationData = signatureData.validationData.decodeValidationData();
        console.log("_signer", signatureData.signer);
        console.logUint(uint256(signatureData.mode));
        console.logUint(signatureData.validationData);
        console.logBytes(signatureData.signature);
        console.log("aggregator: %s", validationData.aggregator);
        console.log("validAfter: %s", validationData.validAfter);
        console.log("validUntil: %s", validationData.validUntil);
    }

}
