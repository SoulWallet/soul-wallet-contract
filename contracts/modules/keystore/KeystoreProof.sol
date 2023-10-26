// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "./IKnownStateRootWithHistory.sol";
import "./MerklePatriciaVerifier.sol";
import "../../keystore/interfaces/IKeyStoreProof.sol";

/**
 * @title KeystoreProof
 * @notice Contract for maintaining and proving a L1 keystore and its storage roots
 */
contract KeystoreProof is IKeyStoreProof {
    mapping(bytes32 => bytes32) public l1SlotToSigningKey;
    mapping(bytes32 => bytes) public l1SlotToRawOwners;
    mapping(bytes32 => uint256) public lastProofBlock;
    mapping(bytes32 => bytes32) public stateRootToKeystoreStorageRoot;

    address public immutable STATE_ROOT_HISTORY_ADDESS;
    address public immutable L1_KEYSTORE_ADDRESS;
    // the latest block number in l1 that proved
    uint256 public latestProofL1BlockNumber;

    event KeyStoreStorageProved(bytes32 stateRoot, bytes32 storageRoot);
    event L1KeyStoreProved(bytes32 l1Slot, bytes32 signingKeyHash);
    /**
     * @param _l1KeystoreAddress Address of L1 Keystore
     * @param _stateRootHistoryAddress Address of state root history contract
     */

    constructor(address _l1KeystoreAddress, address _stateRootHistoryAddress) {
        L1_KEYSTORE_ADDRESS = _l1KeystoreAddress;
        STATE_ROOT_HISTORY_ADDESS = _stateRootHistoryAddress;
    }
    /**
     * @notice Proves the keystore storage root
     * @param stateRoot State root to be proved
     * @param accountProof Proof for the account associated with the state root
     */

    function proofKeystoreStorageRoot(bytes32 stateRoot, bytes memory accountProof) external {
        (bool searchResult, BlockInfo memory currentBlockInfo) =
            IKnownStateRootWithHistory(STATE_ROOT_HISTORY_ADDESS).stateRootInfo(stateRoot);
        require(searchResult, "unkown root");
        require(stateRootToKeystoreStorageRoot[stateRoot] == bytes32(0), "storage root already proved");
        bytes memory keyStoreAccountDetailsBytes = MerklePatriciaVerifier.getValueFromProof(
            currentBlockInfo.storageRootHash, keccak256(abi.encodePacked(L1_KEYSTORE_ADDRESS)), accountProof
        );
        Rlp.Item[] memory keyStoreDetails = Rlp.toList(Rlp.toItem(keyStoreAccountDetailsBytes));
        bytes32 keyStoreStorageRootHash = Rlp.toBytes32(keyStoreDetails[2]);
        stateRootToKeystoreStorageRoot[stateRoot] = keyStoreStorageRootHash;
        if (currentBlockInfo.blockNumber > latestProofL1BlockNumber) {
            latestProofL1BlockNumber = currentBlockInfo.blockNumber;
        }
        emit KeyStoreStorageProved(stateRoot, keyStoreStorageRootHash);
    }
    /**
     * @notice Proves the L1 keystore
     * @param l1Slot Slot of L1 keystore
     * @param stateRoot State root to be proved
     * @param newSigningKey New signing key to be set
     * @param rawOwners Raw owners to be associated with the signing key
     * @param keyProof Proof for the key
     */

    function proofL1Keystore(
        bytes32 l1Slot,
        bytes32 stateRoot,
        bytes32 newSigningKey,
        bytes memory rawOwners,
        bytes memory keyProof
    ) external {
        require(newSigningKey == keccak256(rawOwners), "invalid raw owner data");
        (bool searchResult, BlockInfo memory currentBlockInfo) =
            IKnownStateRootWithHistory(STATE_ROOT_HISTORY_ADDESS).stateRootInfo(stateRoot);
        require(searchResult, "unkown stateRoot root");
        bytes32 keyStoreStorageRootHash = stateRootToKeystoreStorageRoot[stateRoot];
        require(keyStoreStorageRootHash != bytes32(0), "storage root not set");

        // when verify merkel patricia proof for storage value, the tree path = keccaka256("l1slot")
        bytes32 proofSigningKey = Rlp.rlpBytesToBytes32(
            MerklePatriciaVerifier.getValueFromProof(keyStoreStorageRootHash, keccak256(abi.encode(l1Slot)), keyProof)
        );
        require(proofSigningKey == newSigningKey, "key not match");
        // store the new proof signing key to slot mapping

        uint256 blockNumber = lastProofBlock[l1Slot];
        require(currentBlockInfo.blockNumber > blockNumber, "needs to proof newer block");

        l1SlotToSigningKey[l1Slot] = newSigningKey;
        lastProofBlock[l1Slot] = currentBlockInfo.blockNumber;
        l1SlotToRawOwners[l1Slot] = rawOwners;
        emit L1KeyStoreProved(l1Slot, newSigningKey);
    }
    /**
     * @notice Retrieves the signing key hash associated with a given L1 slot
     * @param l1Slot Slot of L1 keystore
     * @return signingKeyHash The signing key hash associated with the L1 slot
     */

    function keystoreBySlot(bytes32 l1Slot) external view returns (bytes32 signingKeyHash) {
        return (l1SlotToSigningKey[l1Slot]);
    }
    /**
     * @notice Retrieves the raw owners associated with a given L1 slot
     * @param l1Slot Slot of L1 keystore
     * @return owners The raw owners associated with the L1 slot
     */

    function rawOwnersBySlot(bytes32 l1Slot) external view override returns (bytes memory owners) {
        return l1SlotToRawOwners[l1Slot];
    }
}
