// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "./interfaces/IKeyStoreStorage.sol";
import "./interfaces/IMerkelTree.sol";
import "./BaseMerkelTree.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title KeyStoreStorage
 * @dev Implements the eternal storage pattern. Provides generic storage capabilities
 * and integrates with a Merkle Tree structure.
 */
contract KeyStoreStorage is IKeyStoreStorage, IMerkleTree, Ownable, BaseMerkleTree {
    // Mapping structure for various data types
    // slot ->key-> value
    mapping(bytes32 => mapping(bytes32 => string)) private stringStorage;
    mapping(bytes32 => mapping(bytes32 => bytes)) private bytesStorage;
    mapping(bytes32 => mapping(bytes32 => uint256)) private uint256Storage;
    mapping(bytes32 => mapping(bytes32 => int256)) private intStorage;
    mapping(bytes32 => mapping(bytes32 => address)) private addressStorage;
    mapping(bytes32 => mapping(bytes32 => bool)) private booleanStorage;
    mapping(bytes32 => mapping(bytes32 => bytes32)) private bytes32Storage;

    // Maps a slot to its corresponding keystore logic implementation
    mapping(bytes32 => address) public slotToKeystoreLogic; // slot => keystore logic implementation
    // Default keystore logic implementation address
    address defaultKeystoreLogic;

    event KeystoreLogicSet(bytes32 indexed slot, address indexed logicAddress);
    event LeafInserted(bytes32 indexed slot, bytes32 signingKeyHash);

    constructor(address _owner) Ownable(_owner) {}
    /**
     * @dev Modifier to ensure that the function caller is an authorized keystore
     * @param slot The slot being accessed
     */

    modifier onlyAuthrizedKeystore(bytes32 slot) {
        if (slotToKeystoreLogic[slot] == address(0)) {
            require(msg.sender == defaultKeystoreLogic, "CALLER_MUST_BE_AUTHORIZED_KEYSTORE");
        } else {
            require(msg.sender == slotToKeystoreLogic[slot], "CALLER_MUST_BE_AUTHORIZED_KEYSTORE");
        }
        _;
    }
    /**
     * @dev Returns the address stored at a specific slot and key.
     * @param _slot The slot of the storage.
     * @param _key The key within the slot.
     * @return Address stored at the slot and key.
     */

    function getAddress(bytes32 _slot, bytes32 _key) external view override returns (address) {
        return addressStorage[_slot][_key];
    }
    /**
     * @dev Returns the uint256 value stored at a specific slot and key.
     * @param _slot The slot of the storage.
     * @param _key The key within the slot.
     * @return uint256 value stored at the slot and key.
     */

    function getUint256(bytes32 _slot, bytes32 _key) external view override returns (uint256) {
        return uint256Storage[_slot][_key];
    }
    /**
     * @dev Returns the string value stored at a specific slot and key.
     * @param _slot The slot of the storage.
     * @param _key The key within the slot.
     * @return string value stored at the slot and key.
     */

    function getString(bytes32 _slot, bytes32 _key) external view override returns (string memory) {
        return stringStorage[_slot][_key];
    }
    /**
     * @dev Returns the bytes value stored at a specific slot and key.
     * @param _slot The slot of the storage.
     * @param _key The key within the slot.
     * @return bytes value stored at the slot and key.
     */

    function getBytes(bytes32 _slot, bytes32 _key) external view override returns (bytes memory) {
        return bytesStorage[_slot][_key];
    }
    /**
     * @dev Returns the boolean value stored at a specific slot and key.
     * @param _slot The slot of the storage.
     * @param _key The key within the slot.
     * @return boolean value stored at the slot and key.
     */

    function getBool(bytes32 _slot, bytes32 _key) external view override returns (bool) {
        return booleanStorage[_slot][_key];
    }
    /**
     * @dev Returns the int256 value stored at a specific slot and key.
     * @param _slot The slot of the storage.
     * @param _key The key within the slot.
     * @return int256 value stored at the slot and key.
     */

    function getInt(bytes32 _slot, bytes32 _key) external view override returns (int256) {
        return intStorage[_slot][_key];
    }
    /**
     * @dev Returns the bytes32 value stored at a specific slot and key.
     * @param _slot The slot of the storage.
     * @param _key The key within the slot.
     * @return bytes32 value stored at the slot and key.
     */

    function getBytes32(bytes32 _slot, bytes32 _key) external view override returns (bytes32) {
        return bytes32Storage[_slot][_key];
    }
    /**
     * @dev Returns the sigin key hash of a specific storage slot.
     * @param _slot The slot of the storage.
     * @return key The represent signing key hash associated with the slot.
     */

    function getSlotValue(bytes32 _slot) external view override returns (bytes32 key) {
        assembly {
            key := sload(_slot)
        }
    }
    /**
     * @dev set the signing key hash of the storage slot.
     * @param _slot The slot to set.
     * @param _value The signing key hash to set.
     */

    function setSlotValue(bytes32 _slot, bytes32 _value) external override onlyAuthrizedKeystore(_slot) {
        assembly {
            sstore(_slot, _value)
        }
    }
    /**
     * @dev Set an address in the storage.
     * @param _slot The slot to set.
     * @param _key The key within the slot.
     * @param _value The address value to set.
     */

    function setAddress(bytes32 _slot, bytes32 _key, address _value) external override onlyAuthrizedKeystore(_slot) {
        addressStorage[_slot][_key] = _value;
    }
    /**
     * @dev Set a uint256 value in the storage.
     * @param _slot The slot to set.
     * @param _key The key within the slot.
     * @param _value The uint256 value to set.
     */

    function setUint256(bytes32 _slot, bytes32 _key, uint256 _value) external override onlyAuthrizedKeystore(_slot) {
        uint256Storage[_slot][_key] = _value;
    }
    /**
     * @dev Set a string value in the storage.
     * @param _slot The slot to set.
     * @param _key The key within the slot.
     * @param _value The string value to set.
     */

    function setString(bytes32 _slot, bytes32 _key, string calldata _value)
        external
        override
        onlyAuthrizedKeystore(_slot)
    {
        stringStorage[_slot][_key] = _value;
    }
    /**
     * @dev Sets the bytes value in storage at a specific slot and key.
     * @param _slot The slot of the storage.
     * @param _key The key within the slot.
     * @param _value The bytes value to set.
     */

    function setBytes(bytes32 _slot, bytes32 _key, bytes calldata _value)
        external
        override
        onlyAuthrizedKeystore(_slot)
    {
        bytesStorage[_slot][_key] = _value;
    }
    /**
     * @dev Sets the boolean value in storage at a specific slot and key.
     * @param _slot The slot of the storage.
     * @param _key The key within the slot.
     * @param _value The boolean value to set.
     */

    function setBool(bytes32 _slot, bytes32 _key, bool _value) external override onlyAuthrizedKeystore(_slot) {
        booleanStorage[_slot][_key] = _value;
    }

    /**
     * @dev Sets the int256 value in storage at a specific slot and key.
     * @param _slot The slot of the storage.
     * @param _key The key within the slot.
     * @param _value The int256 value to set.
     */
    function setInt(bytes32 _slot, bytes32 _key, int256 _value) external override onlyAuthrizedKeystore(_slot) {
        intStorage[_slot][_key] = _value;
    }
    /**
     * @dev Sets the bytes32 value in storage at a specific slot and key.
     * @param _slot The slot of the storage.
     * @param _key The key within the slot.
     * @param _value The bytes32 value to set.
     */

    function setBytes32(bytes32 _slot, bytes32 _key, bytes32 _value) external override onlyAuthrizedKeystore(_slot) {
        bytes32Storage[_slot][_key] = _value;
    }
    /**
     * @dev Insert a new leaf into the merkle tree and emit an event.
     * @param _slot The slot related to the leaf.
     * @param _signingKey The signing key related to the leaf.
     */

    function insertLeaf(bytes32 _slot, bytes32 _signingKey) external override onlyAuthrizedKeystore(_slot) {
        _insertLeaf(_slot, _signingKey);
        emit LeafInserted(_slot, _signingKey);
    }
    /**
     * @dev Assign a new keystore logic implementation to a slot.
     * @param _slot The slot to assign the logic implementation to.
     * @param _logicAddress Address of the logic implementation.
     */

    function setKeystoreLogic(bytes32 _slot, address _logicAddress) external onlyAuthrizedKeystore(_slot) {
        slotToKeystoreLogic[_slot] = _logicAddress;
        emit KeystoreLogicSet(_slot, _logicAddress);
    }

    /**
     * @dev Set the default keystore logic implementation address.
     * @param _defaultKeystoreLogic Address of the default logic implementation.
     */
    function setDefaultKeystoreAddress(address _defaultKeystoreLogic) external onlyOwner {
        require(defaultKeystoreLogic == address(0), "defaultKeystoreLogic already initialized");
        defaultKeystoreLogic = _defaultKeystoreLogic;
    }
}
