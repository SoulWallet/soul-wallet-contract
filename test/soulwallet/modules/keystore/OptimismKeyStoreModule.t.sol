// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@source/modules/keystore/OptimismKeyStoreProofModule/OpKnownStateRootWithHistory.sol";
import "@source/modules/keystore/KeystoreProof.sol";
import "@source/modules/keystore/OptimismKeyStoreProofModule/IL1Block.sol";
import "@source/modules/keystore/KeyStoreModule.sol";
import "../../base/SoulWalletInstence.sol";
import "./MockKeyStoreData.sol";
import "@source/libraries/KeyStoreSlotLib.sol";
import "@source/libraries/TypeConversion.sol";

contract MockL1Block is IL1Block, MockKeyStoreData {
    function hash() external view returns (bytes32) {
        return TEST_BLOCK_HASH;
    }

    function number() external view returns (uint256) {
        return TEST_BLOCK_NUMBER;
    }
}

contract OptimismKeyStoreModuleTest is Test, MockKeyStoreData {
    using stdStorage for StdStorage;
    using TypeConversion for address;

    OpKnownStateRootWithHistory knownStateRootWithHistory;
    MockL1Block mockL1Block;
    KeystoreProof keystoreProofContract;
    SoulWalletInstence public soulWalletInstence;
    ISoulWallet public soulWallet;
    KeyStoreModule optimismKeyStoreModule;

    address public walletOwner;
    address public newOwner = TEST_NEW_OWNER;
    uint256 public walletOwnerPrivateKey;
    bytes32 public walletL1Slot;
    address public initialKey;
    bytes32 public initialKeyBytes32;
    bytes32 public initialGuardianHash;
    uint64 public initialGuardianSafePeriod;

    function setUp() public {
        (walletOwner, walletOwnerPrivateKey) = makeAddrAndKey("owner");
        mockL1Block = new MockL1Block();
        knownStateRootWithHistory = new OpKnownStateRootWithHistory(address(mockL1Block));
        keystoreProofContract = new KeystoreProof(TEST_L1_KEYSTORE,address(knownStateRootWithHistory));
        optimismKeyStoreModule = new KeyStoreModule(address(keystoreProofContract));

        initialKey = makeAddr("initialKey");
        initialKeyBytes32 = bytes32(uint256(uint160(initialKey)));
        initialGuardianHash = keccak256("0x1");
        initialGuardianSafePeriod = 2 days;
        walletL1Slot = KeyStoreSlotLib.getSlot(initialKeyBytes32, initialGuardianHash, initialGuardianSafePeriod);
    }

    function deployWallet() private {
        bytes[] memory modules = new bytes[](1);
        // mock encode slot postion in l1
        bytes memory keystoreModuleInitData =
            abi.encode(initialKeyBytes32, initialGuardianHash, initialGuardianSafePeriod);
        modules[0] = abi.encodePacked(optimismKeyStoreModule, keystoreModuleInitData);
        bytes32 salt = bytes32(0);
        bytes[] memory plugins = new bytes[](0);
        soulWalletInstence = new SoulWalletInstence(address(0), walletOwner,  modules, plugins,  salt);
        soulWallet = soulWalletInstence.soulWallet();

        bytes32 l1Slot = stdstore.target(address(optimismKeyStoreModule)).sig("l1Slot(address)").with_key(
            address(soulWallet)
        ).depth(0).read_bytes32();
        assertEq(walletL1Slot, l1Slot);
        hackModifyKeyStoreSLot();
    }

    function hackModifyKeyStoreSLot() private {
        // hack: modify the wallet slot to TEST_SLOT for hardcoding proof testing
        stdstore.target(address(optimismKeyStoreModule)).sig("l1Slot(address)").with_key(address(soulWallet)).depth(0)
            .checked_write(TEST_SLOT);
        stdstore.target(address(keystoreProofContract)).sig("l1SlotToSigningKey(bytes32)").with_key(walletL1Slot).depth(
            0
        ).checked_write(TEST_NEW_OWNER);
    }

    function test_setUp() public {
        deployWallet();
        (address[] memory _modules,) = soulWallet.listModule();
        assertEq(_modules.length, 1, "module length error");
        assertEq(_modules[0], address(optimismKeyStoreModule), "module address error");
        assertEq(soulWallet.isOwner(walletOwner.toBytes32()), true);
    }

    function proofL1KeyStore() internal {
        bytes memory blockInfoParameter = BLOCK_INFO_BYTES;
        knownStateRootWithHistory.setBlockHash();
        knownStateRootWithHistory.insertNewStateRoot(TEST_BLOCK_NUMBER, blockInfoParameter);
        keystoreProofContract.proofKeystoreStorageRoot(TEST_STATE_ROOT, TEST_ACCOUNT_PROOF);
        keystoreProofContract.proofL1Keystore(TEST_SLOT, TEST_STATE_ROOT, TEST_NEW_OWNER.toBytes32(), TEST_KEY_PROOF);
    }

    function test_setUpWithKeyStoreValueExist() public {
        // hack manually set the proofy key owner
        stdstore.target(address(keystoreProofContract)).sig("l1SlotToSigningKey(bytes32)").with_key(walletL1Slot).depth(
            0
        ).checked_write(TEST_NEW_OWNER);

        proofL1KeyStore();
        deployWallet();
        assertEq(soulWallet.isOwner(walletOwner.toBytes32()), false);
        assertEq(soulWallet.isOwner(newOwner.toBytes32()), true);
    }

    function test_keyStoreSyncWithModule() public {
        deployWallet();
        assertEq(soulWallet.isOwner(walletOwner.toBytes32()), true);
        assertEq(soulWallet.isOwner(newOwner.toBytes32()), false);
        proofL1KeyStore();
        vm.startPrank(walletOwner);
        optimismKeyStoreModule.syncL1Keystore(address(soulWallet));
        assertEq(soulWallet.isOwner(walletOwner.toBytes32()), false);
        assertEq(soulWallet.isOwner(newOwner.toBytes32()), true);
        vm.stopPrank();
    }

    function test_keyStoreSyncWithModuleSyncAgain() public {
        deployWallet();
        assertEq(soulWallet.isOwner(walletOwner.toBytes32()), true);
        assertEq(soulWallet.isOwner(newOwner.toBytes32()), false);
        proofL1KeyStore();
        vm.startPrank(walletOwner);
        optimismKeyStoreModule.syncL1Keystore(address(soulWallet));
        assertEq(soulWallet.isOwner(walletOwner.toBytes32()), false);
        assertEq(soulWallet.isOwner(newOwner.toBytes32()), true);
        vm.expectRevert("keystore already synced");
        optimismKeyStoreModule.syncL1Keystore(address(soulWallet));
        vm.stopPrank();
    }

    function test_keyStoreSyncWithoutKeyStoreInfo() public {
        deployWallet();
        assertEq(soulWallet.isOwner(walletOwner.toBytes32()), true);
        assertEq(soulWallet.isOwner(newOwner.toBytes32()), false);
        vm.startPrank(walletOwner);
        vm.expectRevert("keystore proof not sync");
        optimismKeyStoreModule.syncL1Keystore(address(soulWallet));
        vm.stopPrank();
    }
}
