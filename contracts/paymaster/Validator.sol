// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IValidator.sol";

contract Validator is IValidator, Ownable {


    using UserOperationLib for UserOperation;

    /**
     * @dev Emitted when new wallet logic hash added
     */
    event KnownWalletLogicHashAdd(
        bytes32[] walletCodeHash
    );

    /**
     * @dev Emitted when wallet logic hash removed
     */
    event KnownWalletLogicHashRemove(
        bytes32[] walletCodeHash
    );

     /**
     * @notice The soulwallet proxy bytecode length
     */
    uint256 internal constant SOULPROXY_BYTECODE_LEN = 806;
    /**
     * @notice The soulwallet proxy bytecode hash
     */
    bytes32 internal constant SOULPROXY_BYTECODE_HASH = 0xf09caa9a155fd1b974d15a05d0028ca69e57dfb8cdb663cda591650ca4660f70;

    /**
     * @notice The known wallet logic hash,only the wallet logic in this list can be deployed
     */
    mapping(bytes32 => bool) internal KnownWalletLogicHash;


    constructor() {
        KnownWalletLogicHash[SOULPROXY_BYTECODE_HASH] = true;
    }


    function validate(
        UserOperation memory op
    ) external pure override returns (bool) {
        (op);

        return true;
    }
}
