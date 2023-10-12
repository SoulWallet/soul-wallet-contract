// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Base64Url} from "../libraries/Base64Url.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract Base64UrlTest {
    function encodeBase64UrlTest() external pure returns (bool) {
        bytes32 challenge = 0x83714056da6e6910b51595330c2c2cdfbf718f2deff5bdd84b95df7a7f36f6dd;
        string memory encoded = Base64Url.encode(bytes.concat(challenge));
        require(
            keccak256(bytes(encoded)) == keccak256("g3FAVtpuaRC1FZUzDCws379xjy3v9b3YS5Xfen829t0"),
            "Base64Url encode failed"
        );
        return true;
    }

    function encodeBase64UrlTest(string memory data) external pure returns (string memory encoded) {
        bytes memory dataBytes = bytes(data);
        encoded = Base64Url.encode(dataBytes);
    }

    function encodeBase64Test(string memory data) external pure returns (string memory encoded) {
        bytes memory dataBytes = bytes(data);
        encoded = Base64.encode(dataBytes);
    }
}
