// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Authority} from "@soulwallet-core/contracts/base/Authority.sol";

abstract contract ERC1271Handler is Authority {
    // Magic value indicating a valid signature for ERC-1271 contracts
    // bytes4(keccak256("isValidSignature(bytes32,bytes)")
    bytes4 internal constant MAGICVALUE = 0x1626ba7e;
    // Constants indicating different invalid states
    bytes4 internal constant INVALID_ID = 0xffffffff;

    bytes32 private constant SOUL_WALLET_MSG_TYPEHASH = keccak256("SoulWalletMessage(bytes32 message)");

    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH =
        keccak256("EIP712Domain(uint256 chainId,address verifyingContract)");

    function _encodeRawHash(bytes32 rawHash) internal view returns (bytes32) {
        bytes32 encode1271MessageHash = keccak256(abi.encode(SOUL_WALLET_MSG_TYPEHASH, rawHash));
        bytes32 domainSeparator = keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, getChainId(), address(this)));
        return keccak256(abi.encodePacked(bytes1(0x19), bytes1(0x01), domainSeparator, encode1271MessageHash));
    }

    function getChainId() public view returns (uint256) {
        uint256 id;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            id := chainid()
        }
        return id;
    }
}
