// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./BaseKeyStore.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@solmate/utils/MerkleProofLib.sol";

contract KeyStoreMerkleTree is BaseKeyStore {
    /*
        Multiple Key support in this file.
        The code in the current file is `pseudocode`,
        and this file is purely for demonstrating the flexibility of BaseKeyStore.
    */

    using ECDSA for bytes32;

    IKeyStoreStorage private immutable _KEYSTORE_STORAGE;

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

    /**
     * @dev Verify the signature of the `signKey`
     * @param slot KeyStore slot
     * @param slotNonce used to prevent replay attack
     * @param signKey Current sign key
     * @param action Action type, See ./interfaces/IKeyStore.sol: enum Action
     * @param data {new key(Action.SET_KEY) | new guardian hash(Action.SET_GUARDIAN) | new guardian safe period(Action.SET_GUARDIAN_SAFE_PERIOD) | empty(Action.CANCEL_SET_GUARDIAN | Action.CANCEL_SET_GUARDIAN_SAFE_PERIOD )}
     * @param keySignature `signature of current sign key`
     *
     * Note Implementer must revert if the signature is invalid
     */
    function verifySignature(
        bytes32 slot,
        uint256 slotNonce,
        bytes32 signKey,
        Action action,
        bytes32 data,
        bytes calldata rawOwners,
        bytes calldata keySignature
    ) internal view override {
        // @pseudocode
        {
            (action);
            bytes32 leaf = bytes32(keySignature[0:32]);
            bytes32[] calldata proof;
            bytes calldata signature;

            uint256 proofLength = uint256(bytes32(keySignature[32:64]));
            signature = bytes(keySignature[64 + proofLength:]);
            bytes calldata _proof = keySignature[64:64 + proofLength];
            assembly ("memory-safe") {
                proof.offset := _proof.offset
            }
            bool isValid = MerkleProofLib.verify(proof, signKey, leaf);
            if (!isValid) {
                revert Errors.INVALID_SIGNATURE();
            }

            address signer = _bytes32ToAddress(leaf);
            bytes32 signHash = keccak256(abi.encode(slot, slotNonce, data));
            signHash = signHash.toEthSignedMessageHash();
            (address recovered, ECDSA.RecoverError error) = ECDSA.tryRecover(signHash, signature);
            if (error != ECDSA.RecoverError.NoError && signer != recovered) {
                revert Errors.INVALID_SIGNATURE();
            }
        }
    }

    /**
     * @dev Verify the signature of the `guardian`
     * @param slot KeyStore slot
     * @param slotNonce used to prevent replay attack
     * @param rawGuardian The raw data of the `guardianHash`
     * @param newKey New key
     * @param guardianSignature `signature of current guardian`
     */
    function verifyGuardianSignature(
        bytes32 slot,
        uint256 slotNonce,
        bytes calldata rawGuardian,
        bytes32 newKey,
        bytes calldata guardianSignature
    ) internal pure override {
        // @pseudocode
        (slot, slotNonce, rawGuardian, newKey, guardianSignature);
        revert("TODO: social recovery is not supported yet");
    }

    function keyStoreStorage() public view virtual override returns (IKeyStoreStorage) {
        return _KEYSTORE_STORAGE;
    }
}
