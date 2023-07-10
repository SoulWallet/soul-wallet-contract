// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/interfaces/IERC1271.sol";

contract EIP1271Wallet is IERC1271 {
    bytes4 internal constant MAGICVALUE = 0x1626ba7e;
    bytes4 internal constant INVALID_ID = 0xffffffff;

    function isValidSignature(bytes32 hash, bytes memory signature)
        external
        pure
        override
        returns (bytes4 magicValue)
    {
        (bytes32 _hash, bool _valid) = abi.decode(signature, (bytes32, bool));
        if (_hash != hash || !_valid) {
            return INVALID_ID;
        }
        return MAGICVALUE;
    }
}
