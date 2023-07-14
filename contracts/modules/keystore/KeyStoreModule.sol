pragma solidity ^0.8.17;

import "../BaseModule.sol";
import "./IKeyStoreModule.sol";
import "./BlockVerifier.sol";
import "./MerklePatriciaVerifier.sol";
import "../../libraries/KeyStoreSlotLib.sol";
import "../../keystore/interfaces/IKeystoreProof.sol";

contract KeyStoreModule is IKeyStoreModule, BaseModule {
    bytes4 private constant _FUNC_RESET_OWNER = bytes4(keccak256("resetOwner(address)"));
    bytes4 private constant _FUNC_RESET_OWNERS = bytes4(keccak256("resetOwners(address[])"));

    IKeystoreProof public immutable keyStoreProof;

    mapping(address => bytes32) public l1Slot;
    mapping(address => address) public lastKeyStoreSyncSignKey;

    mapping(address => bool) walletInited;
    uint128 private __seed = 0;

    function _newSeed() private returns (uint128) {
        __seed++;
        return __seed;
    }

    constructor(address _keyStoreProof) {
        keyStoreProof = IKeystoreProof(_keyStoreProof);
    }
    // validate the l1 keystore signing key using merkel patricia proof

    function syncL1Keystore(address wallet) external override {
        bytes32 slotInfo = l1Slot[wallet];
        require(slotInfo != bytes32(0), "wallet slot not set");
        address keystoreSignKey = keyStoreProof.keystoreBySlot(slotInfo);
        require(keystoreSignKey != address(0), "keystore proof not sync");
        address lastSyncKeyStore = lastKeyStoreSyncSignKey[wallet];
        if (lastSyncKeyStore != address(0) && lastSyncKeyStore == keystoreSignKey) {
            revert("keystore already synced");
        }
        ISoulWallet soulwallet = ISoulWallet(payable(wallet));
        soulwallet.resetOwner(keystoreSignKey);
        lastKeyStoreSyncSignKey[wallet] = keystoreSignKey;
        emit KeyStoreSyncd(wallet, keystoreSignKey);
    }

    function requiredFunctions() external pure override returns (bytes4[] memory) {
        bytes4[] memory functions = new bytes4[](2);
        functions[0] = _FUNC_RESET_OWNER;
        functions[1] = _FUNC_RESET_OWNERS;
        return functions;
    }

    function inited(address wallet) internal view virtual override returns (bool) {
        return walletInited[wallet];
    }
    // when wallet add keystore module, it will call this function to set the l1keystore slot mapping

    function _init(bytes calldata _data) internal virtual override {
        address _sender = sender();
        (bytes32 initialKey, bytes32 initialGuardianHash, uint64 guardianSafePeriod) =
            abi.decode(_data, (bytes32, bytes32, uint64));
        bytes32 walletKeyStoreSlot = KeyStoreSlotLib.getSlot(initialKey, initialGuardianHash, guardianSafePeriod);
        require(walletKeyStoreSlot != bytes32(0), "wallet slot needs to set");
        l1Slot[_sender] = walletKeyStoreSlot;

        address keystoreSignKey = keyStoreProof.keystoreBySlot(walletKeyStoreSlot);
        // if keystore already sync, change to keystore signer
        if (keystoreSignKey != address(0)) {
            ISoulWallet soulwallet = ISoulWallet(payable(_sender));
            // sync keystore signing key
            soulwallet.resetOwner(keystoreSignKey);
            lastKeyStoreSyncSignKey[_sender] = keystoreSignKey;
            emit KeyStoreSyncd(_sender, keystoreSignKey);
        }
        walletInited[_sender] = true;
    }

    function _deInit() internal virtual override {
        address _sender = sender();
        delete l1Slot[_sender];
        delete lastKeyStoreSyncSignKey[_sender];
        walletInited[_sender] = false;
    }
}
