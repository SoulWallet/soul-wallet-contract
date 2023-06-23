// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

interface IKeystoreProof {
    function getKeystoreBySlot(bytes32 l1Slot) external view returns (address signingKey, uint256 blockNumber);
}
