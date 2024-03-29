// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IMerkleRoot.sol";

/**
 * @title Merkle Root History Base Contract
 * @dev This base contract is designed for syncing the keystore's Merkle root from Layer 1 (L1) to Layer 2 (L2).
 * Due to the varying implementations of cross-chain messaging across different Layer 2 solutions, this contract,
 * when deployed on a Layer 2 network, requires the `isValidL1Sender` function to be overridden. This is to ensure
 * that only authorized cross-chain message helper contracts from Layer 1 can invoke it. This mechanism is crucial
 * for maintaining a secure and accurate history of the Merkle roots in the L1 keystore
 */
abstract contract MerkleRootHistoryBase is Ownable, IMerkleRoot {
    address public l1Target;
    mapping(uint256 => bytes32) public merkleRoots;
    uint32 public constant ROOT_HISTORY_SIZE = 30;
    uint32 public currentRootIndex;
    bytes32 public latestMerkleRoot;

    constructor(address _l1Target, address _owner) Ownable(_owner) {
        l1Target = _l1Target;
    }

    function updateL1Target(address _l1Target) public onlyOwner {
        l1Target = _l1Target;
    }

    function isKnownRoot(bytes32 _root) public view returns (bool) {
        if (_root == 0) {
            return false;
        }
        uint32 _currentRootIndex = currentRootIndex;
        uint32 i = _currentRootIndex;
        do {
            if (_root == merkleRoots[i]) {
                return true;
            }
            if (i == 0) {
                i = ROOT_HISTORY_SIZE;
            }
            i--;
        } while (i != _currentRootIndex);
        return false;
    }

    function setMerkleRoot(bytes32 l1MerkleRoot) external onlyFromL1 {
        require(l1MerkleRoot != bytes32(0), "merkle root is 0");
        require(isKnownRoot(l1MerkleRoot) == false, "merkle root already known");
        uint32 newRootIndex = (currentRootIndex + 1) % ROOT_HISTORY_SIZE;
        currentRootIndex = newRootIndex;
        merkleRoots[newRootIndex] = l1MerkleRoot;
        latestMerkleRoot = l1MerkleRoot;
        emit L1MerkleRootSynced(l1MerkleRoot, block.number);
    }

    modifier onlyFromL1() {
        require(isValidL1Sender(), "Only L1 allowed");
        _;
    }

    function isValidL1Sender() internal virtual returns (bool);
}
