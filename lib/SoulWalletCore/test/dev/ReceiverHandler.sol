// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

contract ReceiverHandler is IERC721Receiver, IERC1155Receiver {
    bytes4 private constant _ERC721_RECEIVED = IERC721Receiver.onERC721Received.selector;
    bytes4 private constant _ERC1155_RECEIVED = IERC1155Receiver.onERC1155Received.selector;
    bytes4 private constant _ERC1155_BATCH_RECEIVED = IERC1155Receiver.onERC1155BatchReceived.selector;

    bytes4 private constant _INTERFACE_ID_ERC721_RECEIVER = type(IERC721Receiver).interfaceId;
    bytes4 private constant _INTERFACE_ID_ERC1155_RECEIVER = type(IERC1155Receiver).interfaceId;
    bytes4 private constant _INTERFACE_ID_ERC165 = type(IERC165).interfaceId;

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return _ERC721_RECEIVED;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return _ERC1155_RECEIVED;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return _ERC1155_BATCH_RECEIVED;
    }

    function supportsInterface(bytes4 interfaceId) external view virtual override returns (bool) {
        return interfaceId == _INTERFACE_ID_ERC721_RECEIVER || interfaceId == _INTERFACE_ID_ERC1155_RECEIVER
            || interfaceId == _INTERFACE_ID_ERC165;
    }

    receive() external payable {}
    fallback() external payable {}
}
