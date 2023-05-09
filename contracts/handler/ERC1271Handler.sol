// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/interfaces/IERC1271.sol";


contract ERC1271Handler is IERC1271 {
    // bytes4(keccak256("isValidSignature(bytes32,bytes)")
    bytes4 internal constant MAGICVALUE = 0x1626ba7e;

    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view override returns (bytes4 magicValue) {
        //#TODO
        return MAGICVALUE;
    }
}
