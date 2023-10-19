// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./base/SoulWalletInstence.sol";
import "@source/handler/ERC1271Handler.sol";
import "@source/handler/DefaultCallbackHandler.sol";
import "@source/handler/ERC1271Handler.sol";
import "@source/dev/Tokens/TokenERC721.sol";

contract SoulWalletIsValidateSingatureTest is Test {
    SoulWalletInstence public soulWalletInstence;
    DefaultCallbackHandler public defaultCallbackHandler;
    ISoulWallet public soulWallet;
    TokenERC721 tokenERC721;
    address ownwerAddress;
    uint256 ownerPrivateKey;
    bytes4 internal constant MAGICVALUE = 0x1626ba7e;
    bytes4 internal constant INVALID_ID = 0xffffffff;
    bytes4 internal constant INVALID_TIME_RANGE = 0xfffffffe;

    //keccak256(
    //    "SoulWalletMessage(bytes32 message)"
    //);

    bytes32 private constant SOUL_WALLET_MSG_TYPEHASH =
        0x04e6b5b1de6ba008d582849d4956d004d09a345fc11e7ba894975b5b56a4be66;
    // keccak256(
    //     "EIP712Domain(uint256 chainId,address verifyingContract)"
    // );
    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH =
        0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;

    function setUp() public {
        (ownwerAddress, ownerPrivateKey) = makeAddrAndKey("owner1");
        bytes[] memory modules = new bytes[](0);
        bytes[] memory plugins = new bytes[](0);
        bytes32 salt = bytes32(0);
        defaultCallbackHandler = new DefaultCallbackHandler();
        soulWalletInstence =
            new SoulWalletInstence(address(defaultCallbackHandler), ownwerAddress,  modules, plugins,  salt);
        soulWallet = soulWalletInstence.soulWallet();
    }

    function encodeRawHash(bytes32 rawHash, address account) private view returns (bytes32) {
        bytes32 encode1271MessageHash = keccak256(abi.encode(SOUL_WALLET_MSG_TYPEHASH, rawHash));
        bytes32 domainSeparator = keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, getChainId(), account));
        return keccak256(abi.encodePacked(bytes1(0x19), bytes1(0x01), domainSeparator, encode1271MessageHash));
    }

    function getChainId() private view returns (uint256) {
        uint256 id;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            id := chainid()
        }
        return id;
    }

    function test_isValidateSignauture() public {
        bytes32 hash = keccak256(abi.encodePacked("hello world"));
        bytes32 encodeHash = encodeRawHash(hash, address(soulWallet));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, encodeHash);
        bytes memory sig = abi.encodePacked(r, s, v);
        assertEq(sig.length, 65);
        uint8 signType = 0;
        bytes memory validatorSignature = abi.encodePacked(signType, sig);

        uint8 dataType = 0;
        bytes memory signSig = abi.encodePacked(dataType, validatorSignature);

        bytes4 validResult = ERC1271Handler(address(soulWallet)).isValidSignature(hash, signSig);
        assertEq(validResult, MAGICVALUE);
    }
}
