pragma solidity ^0.8.17;

import {IMerkleRoot} from "./interfaces/IMerkleRoot.sol";
import {IKeyStoreProof} from "../../keystore/interfaces/IKeyStoreProof.sol";

/**
 * @title KeyStoreMerkleProof
 * @dev enables L1 keystore signkey verification via Merkle proofs
 * It allows users to prove the latest signing key in the L1 keystore slot.
 * Users submit a Merkle proof that validates their claim to a specific signing key by proving its inclusion in a known Merkle root
 */
contract KeyStoreMerkleProof is IKeyStoreProof {
    mapping(bytes32 => bytes32) public l1SlotToSigningKey;
    mapping(bytes32 => bytes) public l1SlotToRawOwners;
    mapping(bytes32 => uint256) public lastProofBlock;

    address public immutable MERKLE_ROOT_HISTORY;

    event L1KeyStoreProved(bytes32 l1Slot, bytes32 signingKey);

    constructor(address _merkleRootHistory) {
        MERKLE_ROOT_HISTORY = _merkleRootHistory;
    }

    function proveKeyStoreData(
        bytes32 l1Slot,
        bytes32 merkleRoot,
        bytes32 newSigningKey,
        bytes memory rawOwners,
        uint256 blockNumber,
        uint256 index,
        bytes32[] memory proof
    ) external {
        require(newSigningKey == keccak256(rawOwners), "invalid raw owner data");
        require(IMerkleRoot(MERKLE_ROOT_HISTORY).isKnownRoot(merkleRoot), "unkown merkle root");
        uint256 lastProofBlockNumber = lastProofBlock[l1Slot];
        require(blockNumber > lastProofBlockNumber, "block too old");
        require(proof.length == 32, "invalid proof length");
        bytes32 leaf = keccak256(abi.encodePacked(l1Slot, newSigningKey, blockNumber));
        require(verify(proof, merkleRoot, leaf, index), "invalid proof");
        l1SlotToSigningKey[l1Slot] = newSigningKey;
        lastProofBlock[l1Slot] = blockNumber;
        l1SlotToRawOwners[l1Slot] = rawOwners;
        emit L1KeyStoreProved(l1Slot, newSigningKey);
    }

    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf, uint256 index) public pure returns (bool) {
        bytes32 hash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if ((index & 1) == 1) {
                hash = keccak256(abi.encodePacked(proofElement, hash));
            } else {
                hash = keccak256(abi.encodePacked(hash, proofElement));
            }

            index = index / 2;
        }
        return hash == root;
    }

    function keyStoreBySlot(bytes32 l1Slot) external view returns (bytes32 signingKey) {
        return (l1SlotToSigningKey[l1Slot]);
    }

    function rawOwnersBySlot(bytes32 l1Slot) external view override returns (bytes memory owners) {
        return l1SlotToRawOwners[l1Slot];
    }
}
