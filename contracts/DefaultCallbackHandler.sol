// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.12;

import "./interfaces/IERC1155TokenReceiver.sol";
import "./interfaces/IERC721TokenReceiver.sol";
import "./interfaces/IERC777TokensRecipient.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

contract DefaultCallbackHandler is
    IERC1155TokenReceiver,
    IERC777TokensRecipient,
    IERC721TokenReceiver,
    ERC165
{
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return 0xf23a6e61;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        return 0xbc197c81;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return 0x150b7a02;
    }

    function tokensReceived(
        address,
        address,
        address,
        uint256,
        bytes calldata,
        bytes calldata
    ) external pure override {
        // We implement this for completeness, doesn't really have any value
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(IERC1155TokenReceiver).interfaceId ||
            interfaceId == type(IERC721TokenReceiver).interfaceId ||
            interfaceId == type(IERC165).interfaceId || super.supportsInterface(interfaceId);
    }
}
