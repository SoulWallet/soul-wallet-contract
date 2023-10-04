pragma solidity ^0.8.17;

interface IKeyStoreMerkelProof {
    function getMerkleRoot() external view returns (bytes32);
    function getTreeDepth() external pure returns (uint256);
}
// build keystore merkel tree in evm, code build based on eth2 deposit contract

abstract contract BaseMerkleTree is IKeyStoreMerkelProof {
    uint256 constant CONTRACT_TREE_DEPTH = 32;
    uint256 constant MAX_COUNT = 2 ** CONTRACT_TREE_DEPTH - 1;

    bytes32[CONTRACT_TREE_DEPTH] branch;
    uint256 leaf_count;

    bytes32[CONTRACT_TREE_DEPTH] zero_hashes;

    event newLeaf(bytes32 slot, bytes32 signingKey, uint256 blockNo, bytes32 leafNode, uint256 index);

    constructor() {
        for (uint256 height = 0; height < CONTRACT_TREE_DEPTH - 1; height++) {
            zero_hashes[height + 1] = sha256(abi.encodePacked(zero_hashes[height], zero_hashes[height]));
        }
    }

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

    function getTreeCount() external view returns (uint256) {
        return leaf_count;
    }

    function getTreeDepth() external pure returns (uint256) {
        return CONTRACT_TREE_DEPTH;
    }

    function _insertLeaf(bytes32 slot, bytes32 signingKey) internal {
        require(leaf_count < MAX_COUNT, "merkle tree full");
        bytes32 node = sha256(abi.encodePacked(slot, signingKey, block.number));
        emit newLeaf(slot, signingKey, block.number, node, leaf_count);

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
