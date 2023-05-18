// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@source/handler/DefaultCallbackHandler.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

contract DefaultCallbackHandlerTest is Test {
    DefaultCallbackHandler public defaultCallbackHandler;

    function setUp() public {
        defaultCallbackHandler = new DefaultCallbackHandler();
    }

    function test_onERC721Received() public {
        bytes4 selector = defaultCallbackHandler.onERC721Received(address(0), address(0), 0, "");
        assertEq(selector, IERC721Receiver.onERC721Received.selector);
    }

    function test_onERC1155Received() public {
        bytes4 selector = defaultCallbackHandler.onERC1155Received(address(0), address(0), 0, 0, "");
        assertEq(selector, IERC1155Receiver.onERC1155Received.selector);
    }

    function test_onERC1155BatchReceived() public {
        uint256[] memory ids;
        uint256[] memory values;
        bytes4 selector = defaultCallbackHandler.onERC1155BatchReceived(address(0), address(0), ids, values, "");
        assertEq(selector, IERC1155Receiver.onERC1155BatchReceived.selector);
    }
}
