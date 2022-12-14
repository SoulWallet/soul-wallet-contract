// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../UserOperation.sol";

/**
 * @dev Signatures layout used by the Paymasters and Wallets internally
 * @param mode whether it is an owner's or a guardian's signature
 * @param values list of signatures value to validate
 */
struct SignatureData {
    SignatureMode mode;
    address signer;
    bytes signature;
}

/**
 * @dev Signature mode to denote whether it is an owner's or a guardian's signature
 */
enum SignatureMode {
    owner,
    guardians
}

library Signatures {
    /**
     * @dev Decodes a user operation's signature assuming the expected layout defined by the Signatures library
     */
    function decodeSignature(
        UserOperation calldata op
    ) internal pure returns (SignatureData memory) {
        return decodeSignature(op.signature);
    }

    /**
     * @dev Decodes a signature assuming the expected layout defined by the Signatures library
     */
    function decodeSignature(
        bytes memory signature
    ) internal pure returns (SignatureData memory) {
        (SignatureMode _mode, address _singer, bytes memory _signature) = abi
            .decode(signature, (SignatureMode, address, bytes));
        return SignatureData(_mode, _singer, _signature);
    }
}
