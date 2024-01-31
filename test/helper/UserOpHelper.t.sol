// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import "forge-std/Test.sol";

abstract contract UserOpHelper is Test {
    EntryPoint public entryPoint;

    using MessageHashUtils for bytes32;

    constructor() {
        entryPoint = new EntryPoint();
    }

    function signUserOp(PackedUserOperation memory op, uint256 _key, address _validator)
        public
        view
        returns (bytes memory signature)
    {
        bytes32 hash = entryPoint.getUserOpHash(op);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_key, hash.toEthSignedMessageHash());
        bytes memory opSig;
        bytes memory signatureData = abi.encodePacked(r, s, v);
        uint8 signType = 0;
        bytes4 signatureLength = bytes4(uint32(1 + signatureData.length));
        opSig = abi.encodePacked(_validator, signatureLength, signType, signatureData);
        signature = opSig;
    }

    function signUserOp(PackedUserOperation memory op, uint256 _key, address _validator, bytes memory hookData)
        public
        view
        returns (bytes memory signature)
    {
        bytes32 hash = entryPoint.getUserOpHash(op);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_key, hash.toEthSignedMessageHash());
        bytes memory opSig;
        bytes memory signatureData = abi.encodePacked(r, s, v);
        uint8 signType = 0;
        bytes4 signatureLength = bytes4(uint32(1 + signatureData.length));
        opSig = abi.encodePacked(_validator, signatureLength, signType, signatureData, hookData);
        signature = opSig;
    }

    function signUserOp(EntryPoint _entryPoint, PackedUserOperation memory op, uint256 _key, address _validator)
        public
        view
        returns (bytes memory signature)
    {
        bytes32 hash = _entryPoint.getUserOpHash(op);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_key, hash.toEthSignedMessageHash());
        bytes memory opSig;
        bytes memory signatureData = abi.encodePacked(r, s, v);
        uint8 signType = 0;
        bytes4 signatureLength = bytes4(uint32(1 + signatureData.length));
        opSig = abi.encodePacked(_validator, signatureLength, signType, signatureData);
        signature = opSig;
    }

    function signUserOp(
        EntryPoint _entryPoint,
        PackedUserOperation memory op,
        uint256 _key,
        address _validator,
        bytes memory hookData
    ) public view returns (bytes memory signature) {
        bytes32 hash = _entryPoint.getUserOpHash(op);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_key, hash.toEthSignedMessageHash());
        bytes memory opSig;
        bytes memory signatureData = abi.encodePacked(r, s, v);
        uint8 signType = 0;
        bytes4 signatureLength = bytes4(uint32(1 + signatureData.length));
        opSig = abi.encodePacked(_validator, signatureLength, signType, signatureData, hookData);
        signature = opSig;
    }
}
