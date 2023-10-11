// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

interface IKeyStoreStorage {
    // getter
    function getAddress(bytes32 _slot, bytes32 _key) external view returns (address);
    function getUint256(bytes32 _slot, bytes32 _key) external view returns (uint256);
    function getString(bytes32 _slot, bytes32 _key) external view returns (string memory);
    function getBytes(bytes32 _slot, bytes32 _key) external view returns (bytes memory);
    function getBool(bytes32 _slot, bytes32 _key) external view returns (bool);
    function getInt(bytes32 _slot, bytes32 _key) external view returns (int256);
    function getBytes32(bytes32 _slot, bytes32 _key) external view returns (bytes32);
    function getSlotValue(bytes32 _slot) external view returns (bytes32);
    // setter
    function setAddress(bytes32 _slot, bytes32 _key, address _value) external;
    function setUint256(bytes32 _slot, bytes32 _key, uint256 _value) external;
    function setString(bytes32 _slot, bytes32 _key, string calldata _value) external;
    function setBytes(bytes32 _slot, bytes32 _key, bytes calldata _value) external;
    function setBool(bytes32 _slot, bytes32 _key, bool _value) external;
    function setInt(bytes32 _slot, bytes32 _key, int256 _value) external;
    function setBytes32(bytes32 _slot, bytes32 _key, bytes32 _value) external;
    function setSlotValue(bytes32 _slot, bytes32 _value) external;
    function setKeystoreLogic(bytes32 _slot, address _logicAddress) external;
}
