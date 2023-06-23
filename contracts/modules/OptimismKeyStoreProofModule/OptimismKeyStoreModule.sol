pragma solidity ^0.8.17;

import "../BaseModule.sol";
import "./IOptimismKeyStoreModule.sol";
import "./BlockVerifier.sol";
import "./MerklePatriciaVerifier.sol";
import "./IKeystoreProof.sol";

contract OptimismKeyStoreModule is IOptimismKeyStoreModule, BaseModule {
    bytes4 private constant _FUNC_RESET_OWNER = bytes4(keccak256("resetOwner(address)"));
    bytes4 private constant _FUNC_RESET_OWNERS = bytes4(keccak256("resetOwners(address[])"));

    address public immutable keyStoreProof;

    mapping(address => bytes32) public l1Slot;
    mapping(address => address) public lastKeyStoreSyncSignKey;

    mapping(address => uint256) walletInitSeed;
    uint128 private __seed = 0;

    function _newSeed() private returns (uint128) {
        __seed++;
        return __seed;
    }

    constructor(address _keyStoreProof) {
        keyStoreProof = _keyStoreProof;
    }
    // validate the l1 keystore signing key using merkel patricia proof

    function syncL1Keystore(address wallet) external override {
        bytes32 slotInfo = l1Slot[wallet];
        require(slotInfo != bytes32(0), "wallet slot not set");
        (address keystoreSignKey,) = IKeystoreProof(keyStoreProof).getKeystoreBySlot(slotInfo);
        require(keystoreSignKey != address(0), "keystore proof not sync");
        address lastSyncKeyStore = lastKeyStoreSyncSignKey[wallet];
        if (lastSyncKeyStore != address(0) && lastSyncKeyStore == keystoreSignKey) {
            revert("keystore already synced");
        }
        ISoulWallet soulwallet = ISoulWallet(payable(wallet));
        address[] memory _newOwners = new address[](1);
        _newOwners[0] = keystoreSignKey;
        // sync keystore signing key
        soulwallet.resetOwners(_newOwners);
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
        return walletInitSeed[wallet] != 0;
    }
    // when wallet add keystore module, it will call this function to set the l1keystore slot mapping

    function _init(bytes calldata data) internal virtual override {
        address _sender = sender();
        (bytes32 walletKeyStoreSlot) = abi.decode(data, (bytes32));
        require(walletKeyStoreSlot != bytes32(0), "wallet slot needs to set");
        l1Slot[_sender] = walletKeyStoreSlot;
        walletInitSeed[_sender] = _newSeed();

        (address keystoreSignKey,) = IKeystoreProof(keyStoreProof).getKeystoreBySlot(walletKeyStoreSlot);
        // if keystore already sync, change to keystore signer
        if (keystoreSignKey != address(0)) {
            ISoulWallet soulwallet = ISoulWallet(payable(_sender));
            address[] memory _newOwners = new address[](1);
            _newOwners[0] = keystoreSignKey;
            // sync keystore signing key
            soulwallet.resetOwners(_newOwners);
            lastKeyStoreSyncSignKey[_sender] = keystoreSignKey;
            emit KeyStoreSyncd(_sender, keystoreSignKey);
        }
    }

    function _deInit() internal virtual override {
        address _sender = sender();
        walletInitSeed[_sender] = 0;
        delete l1Slot[_sender];
        delete lastKeyStoreSyncSignKey[_sender];
    }
}