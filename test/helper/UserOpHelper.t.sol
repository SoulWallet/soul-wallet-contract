// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@account-abstraction/contracts/interfaces/UserOperation.sol";
import "@account-abstraction/contracts/core/EntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import "forge-std/Test.sol";

abstract contract UserOpHelper is Test {
    EntryPoint public entryPoint;

    using MessageHashUtils for bytes32;

    constructor() {
        entryPoint = new EntryPoint();
    }

    function signUserOp(UserOperation memory op, uint256 _key) public view returns (bytes memory signature) {
        bytes32 hash = entryPoint.getUserOpHash(op);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_key, hash.toEthSignedMessageHash());
        bytes memory opSig;
        bytes memory signatureData = abi.encodePacked(r, s, v);
        uint8 signType = 0;
        uint8 dataType = 0;
        opSig = abi.encodePacked(dataType, signType, signatureData);
        signature = opSig;
    }

    function signUserOp(EntryPoint _entryPoint, UserOperation memory op, uint256 _key)
        public
        view
        returns (bytes memory signature)
    {
        bytes32 hash = _entryPoint.getUserOpHash(op);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_key, hash.toEthSignedMessageHash());
        bytes memory opSig;
        bytes memory signatureData = abi.encodePacked(r, s, v);
        uint8 signType = 0;
        uint8 dataType = 0;
        opSig = abi.encodePacked(dataType, signType, signatureData);
        signature = opSig;
    }
}
