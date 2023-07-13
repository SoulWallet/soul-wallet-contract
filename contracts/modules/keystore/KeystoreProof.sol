pragma solidity ^0.8.17;

import "./IKnownStateRootWithHistory.sol";
import "./MerklePatriciaVerifier.sol";
import "../../keystore/interfaces/IKeystoreProof.sol";

contract KeystoreProof is IKeystoreProof {
    mapping(bytes32 => address) public l1SlotToSigningKey;
    mapping(bytes32 => uint256) public lastProofBlock;
    mapping(bytes32 => bytes32) public stateRootToKeystoreStorageRoot;

    address public immutable STATE_ROOT_HISTORY_ADDESS;
    address public immutable L1_KEYSTORE_ADDRESS;

    event KeyStoreStorageProofed(bytes32 stateRoot, bytes32 storageRoot);
    event L1KeyStoreProofed(bytes32 l1Slot, address signingKey);

    constructor(address _l1KeystoreAddress, address _stateRootHistoryAddress) {
        L1_KEYSTORE_ADDRESS = _l1KeystoreAddress;
        STATE_ROOT_HISTORY_ADDESS = _stateRootHistoryAddress;
    }

    function proofKeystoreStorageRoot(bytes32 stateRoot, bytes memory accountProof) external {
        (bool searchResult, BlockInfo memory currentBlockInfo) =
            IKnownStateRootWithHistory(STATE_ROOT_HISTORY_ADDESS).stateRootInfo(stateRoot);
        require(searchResult, "unkown root");
        require(stateRootToKeystoreStorageRoot[stateRoot] == bytes32(0), "storage root already proofed");
        bytes memory keyStoreAccountDetailsBytes = MerklePatriciaVerifier.getValueFromProof(
            currentBlockInfo.storageRootHash, keccak256(abi.encodePacked(L1_KEYSTORE_ADDRESS)), accountProof
        );
        Rlp.Item[] memory keyStoreDetails = Rlp.toList(Rlp.toItem(keyStoreAccountDetailsBytes));
        bytes32 keyStoreStorageRootHash = Rlp.toBytes32(keyStoreDetails[2]);
        stateRootToKeystoreStorageRoot[stateRoot] = keyStoreStorageRootHash;
        emit KeyStoreStorageProofed(stateRoot, keyStoreStorageRootHash);
    }

    function proofL1Keystore(bytes32 l1Slot, bytes32 stateRoot, address newSigningKey, bytes memory keyProof)
        external
    {
        (bool searchResult, BlockInfo memory currentBlockInfo) =
            IKnownStateRootWithHistory(STATE_ROOT_HISTORY_ADDESS).stateRootInfo(stateRoot);
        require(searchResult, "unkown stateRoot root");
        bytes32 keyStoreStorageRootHash = stateRootToKeystoreStorageRoot[stateRoot];
        require(keyStoreStorageRootHash != bytes32(0), "storage root not set");

        // when verify merkel patricia proof for storage value, the tree path = keccaka256("l1slot")
        address proofAddress = Rlp.rlpBytesToAddress(
            MerklePatriciaVerifier.getValueFromProof(keyStoreStorageRootHash, keccak256(abi.encode(l1Slot)), keyProof)
        );
        require(proofAddress == newSigningKey, "key not match");
        // store the new proof signing key to slot mapping

        uint256 blockNumber = lastProofBlock[l1Slot];
        require(currentBlockInfo.blockNumber > blockNumber, "needs to proof newer block");

        l1SlotToSigningKey[l1Slot] = newSigningKey;
        lastProofBlock[l1Slot] = currentBlockInfo.blockNumber;
        emit L1KeyStoreProofed(l1Slot, newSigningKey);
    }

    function keystoreBySlot(bytes32 l1Slot) external view returns (address signingKey) {
        return (l1SlotToSigningKey[l1Slot]);
    }
}
