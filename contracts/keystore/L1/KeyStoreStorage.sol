// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./interfaces/IKeyStoreStorage.sol";
import "./interfaces/IMerkelTree.sol";
import "./BaseMerkelTree.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// using eternal storage pattern
contract KeyStoreStorage is IKeyStoreStorage, IMerkleTree, Ownable, BaseMerkleTree {
    // storage mapping
    // slot ->key-> value
    mapping(bytes32 => mapping(bytes32 => string)) private stringStorage;
    mapping(bytes32 => mapping(bytes32 => bytes)) private bytesStorage;
    mapping(bytes32 => mapping(bytes32 => uint256)) private uint256Storage;
    mapping(bytes32 => mapping(bytes32 => int256)) private intStorage;
    mapping(bytes32 => mapping(bytes32 => address)) private addressStorage;
    mapping(bytes32 => mapping(bytes32 => bool)) private booleanStorage;
    mapping(bytes32 => mapping(bytes32 => bytes32)) private bytes32Storage;

    // slot can set which kesytore logic write to its storage
    mapping(bytes32 => address) public slotToKeystoreLogic; // slot => keystore logic implementation

    address defaultKeystoreLogic;

    event KeystoreLogicSet(bytes32 indexed slot, address indexed logicAddress);
    event LeafInserted(bytes32 indexed slot, bytes32 signingKey);

    modifier onlyAuthrizedKeystore(bytes32 slot) {
        if (slotToKeystoreLogic[slot] == address(0)) {
            require(msg.sender == defaultKeystoreLogic);
        } else {
            require(msg.sender == slotToKeystoreLogic[slot], "CALLER_MUST_BE_AUTHORIZED_KEYSTORE");
        }
        _;
    }

    function getAddress(bytes32 _slot, bytes32 _key) external view override returns (address) {
        return addressStorage[_slot][_key];
    }

    function getUint256(bytes32 _slot, bytes32 _key) external view override returns (uint256) {
        return uint256Storage[_slot][_key];
    }

    function getString(bytes32 _slot, bytes32 _key) external view override returns (string memory) {
        return stringStorage[_slot][_key];
    }

    function getBytes(bytes32 _slot, bytes32 _key) external view override returns (bytes memory) {
        return bytesStorage[_slot][_key];
    }

    function getBool(bytes32 _slot, bytes32 _key) external view override returns (bool) {
        return booleanStorage[_slot][_key];
    }

    function getInt(bytes32 _slot, bytes32 _key) external view override returns (int256) {
        return intStorage[_slot][_key];
    }

    function getBytes32(bytes32 _slot, bytes32 _key) external view override returns (bytes32) {
        return bytes32Storage[_slot][_key];
    }

    function getSlotValue(bytes32 _slot) external view override returns (bytes32 key) {
        assembly {
            key := sload(_slot)
        }
    }

    function setSlotValue(bytes32 _slot, bytes32 _value) external override onlyAuthrizedKeystore(_slot) {
        assembly {
            sstore(_slot, _value)
        }
    }

    function setAddress(bytes32 _slot, bytes32 _key, address _value) external override onlyAuthrizedKeystore(_slot) {
        addressStorage[_slot][_key] = _value;
    }

    function setUint256(bytes32 _slot, bytes32 _key, uint256 _value) external override onlyAuthrizedKeystore(_slot) {
        uint256Storage[_slot][_key] = _value;
    }

    function setString(bytes32 _slot, bytes32 _key, string calldata _value)
        external
        override
        onlyAuthrizedKeystore(_slot)
    {
        stringStorage[_slot][_key] = _value;
    }

    function setBytes(bytes32 _slot, bytes32 _key, bytes calldata _value)
        external
        override
        onlyAuthrizedKeystore(_slot)
    {
        bytesStorage[_slot][_key] = _value;
    }

    function setBool(bytes32 _slot, bytes32 _key, bool _value) external override onlyAuthrizedKeystore(_slot) {
        booleanStorage[_slot][_key] = _value;
    }

    function setInt(bytes32 _slot, bytes32 _key, int256 _value) external override onlyAuthrizedKeystore(_slot) {
        intStorage[_slot][_key] = _value;
    }

    function setBytes32(bytes32 _slot, bytes32 _key, bytes32 _value) external override onlyAuthrizedKeystore(_slot) {
        bytes32Storage[_slot][_key] = _value;
    }

    function insertLeaf(bytes32 _slot, bytes32 _signingKey) external override onlyAuthrizedKeystore(_slot) {
        _insertLeaf(_slot, _signingKey);
        emit LeafInserted(_slot, _signingKey);
    }

    function setKeystoreLogic(bytes32 _slot, address _logicAddress) external onlyAuthrizedKeystore(_slot) {
        slotToKeystoreLogic[_slot] = _logicAddress;
        emit KeystoreLogicSet(_slot, _logicAddress);
    }

    // admin function, set default keystore address
    function setDefaultKeystoreAddress(address _defaultKeystoreLogic) external onlyOwner {
        require(defaultKeystoreLogic == address(0), "defaultKeystoreLogic already initialized");
        defaultKeystoreLogic = _defaultKeystoreLogic;
    }
}
