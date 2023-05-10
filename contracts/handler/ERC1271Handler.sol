// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../authority/OwnerAuth.sol";


abstract contract ERC1271Handler is IERC1271, OwnerAuth {
    // bytes4(keccak256("isValidSignature(bytes32,bytes)")
    bytes4 internal constant MAGICVALUE = 0x1626ba7e;
    bytes4 internal constant InvalidID = 0xffffffff;

    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view override returns (bytes4 magicValue) {
        if (_isOwner(ECDSA.recover(hash, signature))) {
            return MAGICVALUE;
        }
        bytes32 _hash = ECDSA.toEthSignedMessageHash(hash);
        address recovered = ECDSA.recover(_hash, signature);
        if (_isOwner(recovered)) {
            return MAGICVALUE;
        } else {
            return InvalidID;
        }
    }
}
