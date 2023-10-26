pragma solidity ^0.8.20;

import "../BaseModule.sol";
import "./IKeyStoreModule.sol";
import "./BlockVerifier.sol";
import "./MerklePatriciaVerifier.sol";
import "../../libraries/KeyStoreSlotLib.sol";
import "../../keystore/interfaces/IKeyStoreProof.sol";

/**
 * @title KeyStoreModule
 * @notice module for syncing a L1 keystore
 */
contract KeyStoreModule is IKeyStoreModule, BaseModule {
    bytes4 private constant _FUNC_RESET_OWNER = bytes4(keccak256("resetOwner(bytes32)"));
    bytes4 private constant _FUNC_RESET_OWNERS = bytes4(keccak256("resetOwners(bytes32[])"));

    IKeyStoreProof public immutable keyStoreProof;

    mapping(address => bytes32) public l1Slot;
    mapping(address => bytes32) public lastKeyStoreSyncSignKey;

    mapping(address => bool) walletInited;
    uint128 private __seed = 0;
    /**
     * @notice Internal function to increment and return seed.
     * @return New incremented seed value.
     */

    function _newSeed() private returns (uint128) {
        __seed++;
        return __seed;
    }
    /**
     * @param _keyStoreProof Address of the KeyStoreProof contract.
     */

    constructor(address _keyStoreProof) {
        keyStoreProof = IKeyStoreProof(_keyStoreProof);
    }
    /**
     * @notice Synchronize L1 keystore with the wallet.
     * @param wallet Address of the wallet.
     */

    function syncL1Keystore(address wallet) external override {
        bytes32 slotInfo = l1Slot[wallet];
        require(slotInfo != bytes32(0), "wallet slot not set");
        bytes32 keystoreSignKey = keyStoreProof.keystoreBySlot(slotInfo);
        require(keystoreSignKey != bytes32(0), "keystore proof not sync");
        bytes32 lastSyncKeyStore = lastKeyStoreSyncSignKey[wallet];
        if (lastSyncKeyStore != bytes32(0) && lastSyncKeyStore == keystoreSignKey) {
            revert("keystore already synced");
        }
        ISoulWallet soulwallet = ISoulWallet(payable(wallet));
        bytes memory rawOwners = keyStoreProof.rawOwnersBySlot(slotInfo);
        bytes32[] memory owners = abi.decode(rawOwners, (bytes32[]));
        soulwallet.resetOwners(owners);
        lastKeyStoreSyncSignKey[wallet] = keystoreSignKey;
        emit KeyStoreSyncd(wallet, keystoreSignKey);
    }
    /**
     * @notice Retrieve the list of required functions for the keystore module.
     * @return An array of function selectors.
     */

    function requiredFunctions() external pure override returns (bytes4[] memory) {
        bytes4[] memory functions = new bytes4[](2);
        functions[0] = _FUNC_RESET_OWNER;
        functions[1] = _FUNC_RESET_OWNERS;
        return functions;
    }
    /**
     * @notice Check if a wallet is initialized.
     * @param wallet Address of the wallet.
     * @return True if the wallet is initialized, false otherwise.
     */

    function inited(address wallet) internal view virtual override returns (bool) {
        return walletInited[wallet];
    }
    /**
     * @dev when wallet add keystore module, it will call this function to set the l1keystore slot mapping
     * @notice Internal function to initialize keystore for a wallet.
     * @param _data Initialization data containing initial key hash, guardian hash, and guardian safe period.
     */

    function _init(bytes calldata _data) internal virtual override {
        address _sender = sender();
        (bytes32 initialKeyHash, bytes32 initialGuardianHash, uint64 guardianSafePeriod) =
            abi.decode(_data, (bytes32, bytes32, uint64));
        bytes32 walletKeyStoreSlot = KeyStoreSlotLib.getSlot(initialKeyHash, initialGuardianHash, guardianSafePeriod);
        require(walletKeyStoreSlot != bytes32(0), "wallet slot needs to set");
        l1Slot[_sender] = walletKeyStoreSlot;

        bytes32 keystoreSignKey = keyStoreProof.keystoreBySlot(walletKeyStoreSlot);
        // if keystore already sync, change to keystore signer
        if (keystoreSignKey != bytes32(0)) {
            bytes memory rawOwners = keyStoreProof.rawOwnersBySlot(walletKeyStoreSlot);
            bytes32[] memory owners = abi.decode(rawOwners, (bytes32[]));
            ISoulWallet soulwallet = ISoulWallet(payable(_sender));
            // sync keystore signing key
            soulwallet.resetOwners(owners);
            lastKeyStoreSyncSignKey[_sender] = keystoreSignKey;
            emit KeyStoreSyncd(_sender, keystoreSignKey);
        }
        walletInited[_sender] = true;
        emit KeyStoreInited(_sender, initialKeyHash, initialGuardianHash, guardianSafePeriod);
    }
    /**
     * @notice Internal function to deinitialize keystore for a wallet.
     */

    function _deInit() internal virtual override {
        address _sender = sender();
        delete l1Slot[_sender];
        delete lastKeyStoreSyncSignKey[_sender];
        walletInited[_sender] = false;
    }
}
