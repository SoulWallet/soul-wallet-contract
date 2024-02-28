pragma solidity ^0.8.17;

import "../BaseModule.sol";
import "./interfaces/IKeyStoreModule.sol";
import "../../libraries/KeyStoreSlotLib.sol";
import {IKeyStoreProof} from "../../keystore/interfaces/IKeyStoreProof.sol";

/**
 * @title KeyStoreModule
 * @dev  The KeyStoreModule integrates with wallets to manage signing keys using L1 keystore data.
 * Upon wallet creation, it checks if the keystore has been synced. If so, the wallet's signing key
 * is set to the keystore's signing key. Otherwise, it uses the initial signing key specified during creation.
 * The module also offers functionality to sync the wallet's signing key with the latest from the L1 keystore
 * via the `syncL1Keystore` method. This ensures wallet signing keys can be dynamically updated to reflect
 * changes in the keystore
 */

contract KeyStoreModule is IKeyStoreModule, BaseModule {
    bytes4 private constant _FUNC_RESET_OWNER = bytes4(keccak256("resetOwner(bytes32)"));
    bytes4 private constant _FUNC_RESET_OWNERS = bytes4(keccak256("resetOwners(bytes32[])"));

    IKeyStoreProof public immutable keyStoreProof;

    mapping(address => bytes32) public l1Slot;
    mapping(address => bytes32) public latestSyncedSignKey;

    mapping(address => bool) walletInited;

    constructor(address _keyStoreProof) {
        keyStoreProof = IKeyStoreProof(_keyStoreProof);
    }

    function _deInit() internal override {
        address _sender = sender();
        delete l1Slot[_sender];
        delete latestSyncedSignKey[_sender];
        walletInited[_sender] = false;
    }

    function _init(bytes calldata _data) internal override {
        address _sender = sender();
        (bytes32 initialKeyHash, bytes32 initialGuardianHash, uint64 guardianSafePeriod) =
            abi.decode(_data, (bytes32, bytes32, uint64));
        bytes32 walletKeyStoreSlot = KeyStoreSlotLib.getSlot(initialKeyHash, initialGuardianHash, guardianSafePeriod);
        require(walletKeyStoreSlot != bytes32(0), "wallet slot needs to set");
        l1Slot[_sender] = walletKeyStoreSlot;

        bytes32 keystoreSignKey = keyStoreProof.keyStoreBySlot(walletKeyStoreSlot);
        // if keystore already sync, change to keystore signer
        if (keystoreSignKey != bytes32(0)) {
            bytes memory rawOwners = keyStoreProof.rawOwnersBySlot(walletKeyStoreSlot);
            bytes32[] memory owners = abi.decode(rawOwners, (bytes32[]));
            ISoulWallet soulwallet = ISoulWallet(payable(_sender));
            // sync keystore signing key
            soulwallet.resetOwners(owners);
            latestSyncedSignKey[_sender] = keystoreSignKey;
            emit KeyStoreSynced(_sender, keystoreSignKey);
        }
        walletInited[_sender] = true;
        emit KeyStoreInited(_sender, initialKeyHash, initialGuardianHash, guardianSafePeriod);
    }

    function inited(address wallet) internal view override returns (bool) {
        return walletInited[wallet];
    }

    function requiredFunctions() external pure override returns (bytes4[] memory) {
        bytes4[] memory functions = new bytes4[](2);
        functions[0] = _FUNC_RESET_OWNER;
        functions[1] = _FUNC_RESET_OWNERS;
        return functions;
    }

    function syncL1Keystore(address wallet) external override {
        bytes32 slotInfo = l1Slot[wallet];
        require(slotInfo != bytes32(0), "wallet slot not set");
        bytes32 keystoreSignKey = keyStoreProof.keyStoreBySlot(slotInfo);
        require(keystoreSignKey != bytes32(0), "keystore proof not sync");
        bytes32 lastSyncKeyStore = latestSyncedSignKey[wallet];
        if (lastSyncKeyStore != bytes32(0) && lastSyncKeyStore == keystoreSignKey) {
            revert("keystore already synced");
        }
        ISoulWallet soulwallet = ISoulWallet(payable(wallet));
        bytes memory rawOwners = keyStoreProof.rawOwnersBySlot(slotInfo);
        bytes32[] memory owners = abi.decode(rawOwners, (bytes32[]));
        soulwallet.resetOwners(owners);
        latestSyncedSignKey[wallet] = keystoreSignKey;
        emit KeyStoreSynced(wallet, keystoreSignKey);
    }
}
