
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title Validator Interface
 * @dev This interface defines the functionalities for signature validation and hash encoding
 */
interface IKeyStoreValidator {
    /**
     * @dev Recover the signer of a given raw hash using the provided raw signature
     * @param rawHash The raw hash that was signed
     * @param rawSignature The signature data
     * @return recovered The recovered signer's signing key from the signature
     * @return success A boolean indicating the success of the recovery
     */
    function recoverSignature(bytes32 rawHash, bytes calldata rawSignature)
        external
        view
        returns (bytes32 recovered, bool success);
}
