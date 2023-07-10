// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@source/modules/keystore/OptimismKeyStoreProofModule/OpKnownStateRootWithHistory.sol";
import "@source/modules/keystore/KeystoreProof.sol";
import "@source/modules/keystore/OptimismKeyStoreProofModule/IL1Block.sol";
import "@source/modules/keystore/KeyStoreModule.sol";
import "../../base/SoulWalletInstence.sol";
import "./MockKeyStoreData.sol";

contract MockL1Block is IL1Block, MockKeyStoreData {
    function hash() external returns (bytes32) {
        return TEST_BLOCK_HASH;
    }
}

contract OptimismKeyStoreModuleTest is Test, MockKeyStoreData {
    OpKnownStateRootWithHistory knownStateRootWithHistory;
    MockL1Block mockL1Block;
    KeystoreProof keystoreProofContract;
    SoulWalletInstence public soulWalletInstence;
    ISoulWallet public soulWallet;
    KeyStoreModule optimismKeyStoreModule;

    address public walletOwner;
    address public newOwner = TEST_NEW_OWNER;
    uint256 public walletOwnerPrivateKey;

    function setUp() public {
        (walletOwner, walletOwnerPrivateKey) = makeAddrAndKey("owner");
        mockL1Block = new MockL1Block();
        knownStateRootWithHistory = new OpKnownStateRootWithHistory(address(mockL1Block));
        keystoreProofContract =
            new KeystoreProof(0xACB5b53F9F193b99bcd8EF8544ddF4c398DE24a3,address(knownStateRootWithHistory));
        optimismKeyStoreModule = new KeyStoreModule(address(keystoreProofContract));
    }

    function deployWallet() private {
        bytes[] memory modules = new bytes[](1);
        // mock encode slot postion in l1
        modules[0] = abi.encodePacked(optimismKeyStoreModule, abi.encode(0x5));
        bytes32 salt = bytes32(0);
        bytes[] memory plugins = new bytes[](0);
        soulWalletInstence = new SoulWalletInstence(address(0), walletOwner,  modules, plugins,  salt);
        soulWallet = soulWalletInstence.soulWallet();
    }

    function test_setUp() public {
        deployWallet();
        (address[] memory _modules,) = soulWallet.listModule();
        assertEq(_modules.length, 1, "module length error");
        assertEq(_modules[0], address(optimismKeyStoreModule), "module address error");
        assertEq(soulWallet.isOwner(walletOwner), true);
    }

    function proofL1KeyStore() internal {
        bytes memory blockInfoParameter = BLOCK_INFO_BYTES;
        knownStateRootWithHistory.insertNewStateRoot(blockInfoParameter);
        keystoreProofContract.proofKeystoreStorageRoot(TEST_STATE_ROOT, TEST_ACCOUNT_PROOF);
        keystoreProofContract.proofL1Keystore(TEST_SLOT, TEST_STATE_ROOT, TEST_NEW_OWNER, TEST_KEY_PROOF);
    }

    function test_setUpWithKeyStoreValueExist() public {
        proofL1KeyStore();
        deployWallet();
        assertEq(soulWallet.isOwner(walletOwner), false);
        assertEq(soulWallet.isOwner(newOwner), true);
    }

    function test_keyStoreSyncWithModule() public {
        deployWallet();
        assertEq(soulWallet.isOwner(walletOwner), true);
        assertEq(soulWallet.isOwner(newOwner), false);
        proofL1KeyStore();
        vm.startPrank(walletOwner);
        optimismKeyStoreModule.syncL1Keystore(address(soulWallet));
        assertEq(soulWallet.isOwner(walletOwner), false);
        assertEq(soulWallet.isOwner(newOwner), true);
        vm.stopPrank();
    }

    function test_keyStoreSyncWithModuleSyncAgain() public {
        deployWallet();
        assertEq(soulWallet.isOwner(walletOwner), true);
        assertEq(soulWallet.isOwner(newOwner), false);
        proofL1KeyStore();
        vm.startPrank(walletOwner);
        optimismKeyStoreModule.syncL1Keystore(address(soulWallet));
        assertEq(soulWallet.isOwner(walletOwner), false);
        assertEq(soulWallet.isOwner(newOwner), true);
        vm.expectRevert("keystore already synced");
        optimismKeyStoreModule.syncL1Keystore(address(soulWallet));
        vm.stopPrank();
    }

    function test_keyStoreSyncWithoutKeyStoreInfo() public {
        deployWallet();
        assertEq(soulWallet.isOwner(walletOwner), true);
        assertEq(soulWallet.isOwner(newOwner), false);
        vm.startPrank(walletOwner);
        vm.expectRevert("keystore proof not sync");
        optimismKeyStoreModule.syncL1Keystore(address(soulWallet));
        vm.stopPrank();
    }
}
