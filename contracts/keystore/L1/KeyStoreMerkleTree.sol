// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./BaseKeyStore.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@solmate/utils/MerkleProofLib.sol";

contract KeyStoreMerkleTree is BaseKeyStore {
    /*
        The code in the current file is `pseudocode`, 
        and this file is purely for demonstrating the flexibility of BaseKeyStore.
    */

    using ECDSA for bytes32;

    function _bytes32ToAddress(bytes32 key) private view returns (address) {
        // @pseudocode
        {
            address _key;
            assembly ("memory-safe") {
                _key := key
            }
            // check if key is Address
            if (key != bytes32(uint256(uint160(_key)))) {
                revert Errors.INVALID_KEY();
            }

            // check if key not a deployed contract
            bool isDeployedContract;
            assembly {
                isDeployedContract := gt(extcodesize(_key), 0)
            }
            if (isDeployedContract) {
                revert Errors.INVALID_KEY();
            }
            return _key;
        }
    }

    function _validateKeySignature(bytes32 keyRoot, bytes32 signHash, bytes calldata keySignature)
        internal
        virtual
        override
    {
        // @pseudocode
        {
            bytes32 leaf = bytes32(keySignature[0:32]);
            bytes32[] calldata proof;
            bytes calldata signature;

            uint256 proofLength = uint256(bytes32(keySignature[32:64]));
            signature = bytes(keySignature[64 + proofLength:]);
            bytes calldata _proof = keySignature[64:64 + proofLength];
            assembly ("memory-safe") {
                proof.offset := _proof.offset
            }
            bool isValid = MerkleProofLib.verify(proof, keyRoot, leaf);
            if (!isValid) {
                revert Errors.INVALID_SIGNATURE();
            }

            address signer = _bytes32ToAddress(leaf);
            signHash = signHash.toEthSignedMessageHash();
            (address recovered, ECDSA.RecoverError error) = ECDSA.tryRecover(signHash, signature);
            if (error != ECDSA.RecoverError.NoError && signer != recovered) {
                revert Errors.INVALID_SIGNATURE();
            }
        }
    }

    function _validateGuardianSignature(
        bytes32 guardianHash,
        bytes calldata rawGuardian,
        bytes32 signHash,
        bytes calldata keySignature
    ) internal virtual override {
        (guardianHash, rawGuardian, signHash, keySignature);
        revert("TODO: social recovery is not supported yet");
    }
}
