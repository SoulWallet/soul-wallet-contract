pragma solidity ^0.8.20;

/**
 * @title Interface for KeyStore Merkle Proof
 */
interface IKeyStoreMerkelProof {
    /**
     * @notice Gets the merkle root of the tree
     * @return The merkle root
     */
    function getMerkleRoot() external view returns (bytes32);
    /**
     * @notice Gets the depth of the tree
     * @return The tree depth
     */
    function getTreeDepth() external pure returns (uint256);
}

/**
 * @title Implementation of a Merkle Tree structure
 * @dev This contract allows for the construction of a merkle tree based on the Ethereum 2.0 deposit contract
 */
abstract contract BaseMerkleTree is IKeyStoreMerkelProof {
    uint256 constant CONTRACT_TREE_DEPTH = 32;
    uint256 constant MAX_COUNT = 2 ** CONTRACT_TREE_DEPTH - 1;

    bytes32[CONTRACT_TREE_DEPTH] branch;
    uint256 leaf_count;

    bytes32[CONTRACT_TREE_DEPTH] zero_hashes;

    event newLeaf(bytes32 slot, bytes32 signingKeyHash, uint256 blockNo, bytes32 leafNode, uint256 index);

    /**
     * @dev Constructor initializes the zero hashes
     */
    constructor() {
        for (uint256 height = 0; height < CONTRACT_TREE_DEPTH - 1; height++) {
            zero_hashes[height + 1] = sha256(abi.encodePacked(zero_hashes[height], zero_hashes[height]));
        }
    }
    /**
     * @notice Fetch the current root of the merkle tree
     * @return The merkle root
     */

    function getMerkleRoot() external view returns (bytes32) {
        bytes32 node;
        uint256 size = leaf_count;
        for (uint256 height = 0; height < CONTRACT_TREE_DEPTH; height++) {
            if ((size & 1) == 1) {
                node = sha256(abi.encodePacked(branch[height], node));
            } else {
                node = sha256(abi.encodePacked(node, zero_hashes[height]));
            }
            size /= 2;
        }
        return node;
    }

    /**
     * @notice Fetches the current count of leaves in the tree
     * @return The count of leaves
     */
    function getTreeCount() external view returns (uint256) {
        return leaf_count;
    }
    /**
     * @notice Fetches the depth of the tree
     * @return The depth of the tree
     */

    function getTreeDepth() external pure returns (uint256) {
        return CONTRACT_TREE_DEPTH;
    }
    /**
     * @dev Inserts a new leaf into the merkle tree
     * @param slot The slot for the leaf
     * @param signingKeyHash The hash of the signing key
     */

    function _insertLeaf(bytes32 slot, bytes32 signingKeyHash) internal {
        require(leaf_count < MAX_COUNT, "merkle tree full");
        bytes32 node = sha256(abi.encodePacked(slot, signingKeyHash, block.number));
        emit newLeaf(slot, signingKeyHash, block.number, node, leaf_count);

        leaf_count += 1;
        uint256 size = leaf_count;
        for (uint256 height = 0; height < CONTRACT_TREE_DEPTH; height++) {
            if ((size & 1) == 1) {
                branch[height] = node;
                return;
            }
            node = sha256(abi.encodePacked(branch[height], node));
            size /= 2;
        }
    }
}
