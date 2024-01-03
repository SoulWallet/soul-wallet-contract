// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@source/keystore/L1/KeyStore.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "@source/modules/keystore/arbitrum/ArbMerkleRootHistory.sol";
import "@source/modules/keystore/KeyStoreMerkleProof.sol";
import "@source/modules/keystore/arbitrum/ArbKeyStoreCrossChainMerkleRootManager.sol";
import "@source/validator/KeyStoreValidator.sol";
import "@source/keystore/L1/KeyStoreStorage.sol";
import {ArbitrumInboxMock} from "./ArbitrumInboxMock.sol";

import {KeyStoreModule} from "@source/modules/keystore/KeyStoreModule.sol";
import "../../soulwallet/base/SoulWalletInstence.sol";

contract KeystoreModuleTest is Test {
    using TypeConversion for address;
    using stdStorage for StdStorage;
    using ECDSA for bytes32;

    uint256 constant CONTRACT_TREE_DEPTH = 32;
    bytes32[CONTRACT_TREE_DEPTH] zeros;

    KeyStore keyStoreContract;
    KeyStoreMerkleProof keyStoreMerkleProof;
    KeyStoreValidator keyStoreValidator;
    KeyStoreStorage keyStoreStorage;
    KeyStoreModule keyStoreModule;

    SoulWalletInstence soulWalletInstence;

    bytes32 private constant _TYPE_HASH_SET_KEY =
        keccak256("SetKey(bytes32 keyStoreSlot,uint256 nonce,bytes32 newSigner)");

    bytes32 private constant _TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 private DOMAIN_SEPARATOR;
    uint256 TEST_BLOCK_NUMBER = 100;
    address owner;
    ArbKeyStoreCrossChainMerkleRootManager l1Contract;
    ArbitrumInboxMock inboxMock;
    ArbMerkleRootHistory l2Contract;

    bytes32 slot;
    bytes32 initialKeyHash;
    bytes32 initialGuardianHash;
    address _initialKey;
    uint256 _initialPrivateKey;
    uint64 initialGuardianSafePeriod = 2 days;

    bytes32 initialKey_new_1;
    address _initialKey_new_1;
    uint256 _initialPrivateKey_new_1;
    bytes rawOwners;

    constructor() {
        for (uint256 height = 0; height < CONTRACT_TREE_DEPTH - 1; height++) {
            zeros[height + 1] = keccak256(abi.encodePacked(zeros[height], zeros[height]));
        }
    }

    function setUp() public {
        owner = makeAddr("owner");
        vm.deal(owner, 10 ether);
        vm.startPrank(owner);
        keyStoreValidator = new KeyStoreValidator();
        keyStoreStorage = new KeyStoreStorage(owner);
        keyStoreContract = new KeyStore(keyStoreValidator, keyStoreStorage, owner);
        keyStoreStorage.setDefaultKeystoreAddress(address(keyStoreContract));

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                _TYPEHASH, keccak256(bytes("KeyStore")), keccak256(bytes("1")), block.chainid, address(keyStoreContract)
            )
        );
        inboxMock = new ArbitrumInboxMock();
        l2Contract = new ArbMerkleRootHistory(address(0), owner);
        l1Contract =
            new ArbKeyStoreCrossChainMerkleRootManager(address(0), address(keyStoreStorage), address(inboxMock), owner);
        l2Contract.updateL1Target(address(l1Contract));
        l1Contract.updateL2Target(address(l2Contract));
        keyStoreMerkleProof = new KeyStoreMerkleProof(address(l2Contract));
        keyStoreModule = new KeyStoreModule(address(keyStoreMerkleProof));
        vm.stopPrank();

        initialGuardianHash = keccak256("0x1");
        (_initialKey, _initialPrivateKey) = makeAddrAndKey("initialKeyHash");
        (_initialKey_new_1, _initialPrivateKey_new_1) = makeAddrAndKey("initialKey_new_1");

        keystoreSetKey();
        setL2MerkelRoot();
        merkelProof();
    }

    function merkelProof() private {
        bytes32[] memory proofs = new bytes32[](keyStoreStorage.getTreeDepth());
        for (uint256 i = 0; i < keyStoreStorage.getTreeDepth(); i++) {
            proofs[i] = zeros[i];
        }
        keyStoreMerkleProof.proveKeyStoreData(
            slot, keyStoreStorage.getMerkleRoot(), initialKey_new_1, rawOwners, TEST_BLOCK_NUMBER, 0, proofs
        );

        assertEq(rawOwners, keyStoreMerkleProof.rawOwnersBySlot(slot));
    }

    function setL2MerkelRoot() private {
        address l2Alias = AddressAliasHelper.applyL1ToL2Alias(address(l1Contract));
        vm.deal(l2Alias, 100 ether);
        vm.startPrank(l2Alias);
        l2Contract.setMerkleRoot(keyStoreStorage.getMerkleRoot());
    }

    function keystoreSetKey() private {
        address[] memory owners = new address[](1);
        owners[0] = _initialKey;
        initialKeyHash = keccak256(abi.encode(owners));

        address[] memory newOwners = new address[](1);
        newOwners[0] = _initialKey_new_1;
        rawOwners = abi.encode(newOwners);
        initialKey_new_1 = keccak256(abi.encode(newOwners));
        uint256 nonce = keyStoreContract.nonce(slot);
        assertEq(nonce, 0, "nonce != 0");
        slot = keyStoreContract.getSlot(initialKeyHash, initialGuardianHash, initialGuardianSafePeriod);

        bytes32 structHash = keccak256(abi.encode(_TYPE_HASH_SET_KEY, slot, nonce, initialKey_new_1));
        bytes32 typedDataHash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_initialPrivateKey, typedDataHash);
        bytes memory keySignature = abi.encodePacked(r, s, v);
        uint8 signType = 0;
        bytes memory validatorSignature = abi.encodePacked(signType, keySignature);

        vm.roll(TEST_BLOCK_NUMBER);

        keyStoreContract.setKeyByOwner(
            initialKeyHash,
            initialGuardianHash,
            initialGuardianSafePeriod,
            abi.encode(newOwners),
            abi.encode(owners),
            validatorSignature
        );

        bytes32 merkelRootCal;
        bytes32 node = keccak256(abi.encodePacked(slot, initialKey_new_1, TEST_BLOCK_NUMBER));
        console.logBytes32(node);

        for (uint256 i = 0; i < keyStoreStorage.getTreeDepth(); i++) {
            merkelRootCal = keccak256(abi.encodePacked(node, zeros[i]));
            node = merkelRootCal;
        }
        assertEq(merkelRootCal, keyStoreStorage.getMerkleRoot());
    }

    function deployWallet() private {
        bytes[] memory modules = new bytes[](1);
        bytes[] memory hooks = new bytes[](0);
        bytes32[] memory owners = new bytes32[](1);
        owners[0] = address(_initialKey).toBytes32();
        console.log("rawOwnersBySlot");
        console.logBytes(keyStoreMerkleProof.rawOwnersBySlot(slot));

        bytes memory keystoreModuleInitData = abi.encode(initialKeyHash, initialGuardianHash, initialGuardianSafePeriod);

        modules[0] = abi.encodePacked(keyStoreModule, keystoreModuleInitData);
        bytes32 salt = bytes32(0);
        soulWalletInstence = new SoulWalletInstence(address(0), owners,  modules, hooks,  salt);
        ISoulWallet soulWallet = soulWalletInstence.soulWallet();
        assertEq(soulWallet.isOwner(_initialKey.toBytes32()), false);
        assertEq(soulWallet.isOwner(_initialKey_new_1.toBytes32()), true);
    }

    function test_deployWalletWithKeystoreModule() public {
        deployWallet();
    }
}
