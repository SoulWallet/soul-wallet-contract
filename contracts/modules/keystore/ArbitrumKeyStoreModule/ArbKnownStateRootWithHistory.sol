// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "../KnownStateRootWithHistoryBase.sol";
import "@arbitrum/nitro-contracts/src/precompiles/ArbSys.sol";
import "@arbitrum/nitro-contracts/src/libraries/AddressAliasHelper.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
/* 
 * @title ArbKnownStateRootWithHistory
 * @notice This contract is an extension of `KnownStateRootWithHistoryBase` and keeps a record of block hashes 
 *         for specific block numbers ensuring they are set by a trusted entity on L1 on Arbitrum network.
 */

contract ArbKnownStateRootWithHistory is KnownStateRootWithHistoryBase, Ownable {
    /* @notice Address of the target contract on Layer 1 (L1). */
    address public l1Target;
    /* 
     * @dev Initializes the `l1Target` address and the `owner` of the contract.
     * @param _l1Target Address of the target contract on L1.
     * @param _owner Owner's address.
     */

    constructor(address _l1Target, address _owner) Ownable(_owner) {
        l1Target = _l1Target;
    }
    /* 
     * @notice Updates the `l1Target` address.
     * @param _l1Target New address of the target contract on L1.
     */

    function updateL1Target(address _l1Target) public onlyOwner {
        l1Target = _l1Target;
    }
    /* 
     * @notice Sets the hash for a specific block number.
     * @dev This function requires:
     *      - Message is coming from the L1 target contract's L2 alias.
     *      - Block number is not 0.
     *      - Block hash is not the zero hash.
     * @param l1BlockNumber Block number on L1.
     * @param l1BlockHash Block hash corresponding to the block number.
     */

    function setBlockHash(uint256 l1BlockNumber, bytes32 l1BlockHash) external {
        // To check that message came from L1, we check that the sender is the L1 contract's L2 alias.
        require(msg.sender == AddressAliasHelper.applyL1ToL2Alias(l1Target), "blockhash only updateable by L1Target");
        require(l1BlockNumber != 0, "l1 block number is 0");
        require(l1BlockHash != bytes32(0), "l1 block hash is 0");
        blockHashs[l1BlockNumber] = l1BlockHash;
        emit L1BlockSyncd(l1BlockNumber, l1BlockHash);
    }
}
