pragma solidity ^0.8.17;

import "./IKnownStateRootWithHistory.sol";
import "./MerklePatriciaVerifier.sol";
import "./IKeystoreProof.sol";

contract KeystoreProof is IKeystoreProof {
    mapping(bytes32 => address) public l1SlotToSigningKey;
    mapping(bytes32 => uint256) public lastProofBlock;

    address public immutable STATE_ROOT_HISTORY_ADDESS;
    address public immutable L1_KEYSTORE_ADDRESS;

    constructor(address _l1KeystoreAddress, address _stateRootHistoryAddress) {
        L1_KEYSTORE_ADDRESS = _l1KeystoreAddress;
        STATE_ROOT_HISTORY_ADDESS = _stateRootHistoryAddress;
    }

    function proofL1Keystore(
        bytes32 l1Slot,
        bytes32 stateRoot,
        bytes memory accountProof,
        address newSigningKey,
        bytes memory keyProof
    ) external {
        (bool searchResult, BlockInfo memory currentBlockInfo) =
            IKnownStateRootWithHistory(STATE_ROOT_HISTORY_ADDESS).findStateRootInfo(stateRoot);
        require(searchResult, "unkown root");
        bytes memory keyStoreAccountDetailsBytes = MerklePatriciaVerifier.getValueFromProof(
            currentBlockInfo.storageRootHash, keccak256(abi.encodePacked(L1_KEYSTORE_ADDRESS)), accountProof
        );
        Rlp.Item[] memory keyStoreDetails = Rlp.toList(Rlp.toItem(keyStoreAccountDetailsBytes));
        bytes32 keyStoreStorageRootHash = Rlp.toBytes32(keyStoreDetails[2]);
        // when verify merkel patricia proof for storage value, the tree path = keccaka256("l1slot")
        address proofAddress =
            Rlp.rlpBytesToAddress(MerklePatriciaVerifier.getValueFromProof(keyStoreStorageRootHash, keccak256(abi.encode(l1Slot)), keyProof));
        require(proofAddress == newSigningKey, "key not match");
        // store the new proof signing key to slot mapping

        uint256 blockNumber = lastProofBlock[l1Slot];
        require(currentBlockInfo.blockNumber > blockNumber, "needs to proof newer block");

        l1SlotToSigningKey[l1Slot] = newSigningKey;
        lastProofBlock[l1Slot] = currentBlockInfo.blockNumber;
    }

    function getKeystoreBySlot(bytes32 l1Slot) external view returns (address signingKey, uint256 blockNumber) {
        return (l1SlotToSigningKey[l1Slot], lastProofBlock[l1Slot]);
    }
}
