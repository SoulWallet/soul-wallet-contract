// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IHook, UserOperation} from "@soulwallet-core/contracts/interface/IHook.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "forge-std/console.sol";

contract Crypto2FAHook is IHook {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    uint256 public constant TIME_LOCK_DURATION = 1 days;

    struct User2FA {
        bool initialized;
        address wallet2FAAddr;
        address pending2FAAddr;
        uint256 effectiveTime;
    }

    mapping(address => User2FA) public user2FA;

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IHook).interfaceId;
    }

    function Init(bytes calldata data) external override {
        console.logBytes(data);
        User2FA storage _user2fa = user2FA[msg.sender];
        require(_user2fa.initialized == false, "already initialized");
        address wallet2FAAddr = address(bytes20(data[:20]));
        _user2fa.initialized = true;
        _user2fa.wallet2FAAddr = wallet2FAAddr;
    }

    function DeInit() external override {
        User2FA storage _user2fa = user2FA[msg.sender];
        require(_user2fa.initialized == true, "cannot deinit");
        delete  user2FA[msg.sender];
    }

    function preIsValidSignatureHook(bytes32 hash, bytes calldata hookSignature) external view override {
        address recoveredAddress = hash.toEthSignedMessageHash().recover(hookSignature);
        require(recoveredAddress == user2FA[msg.sender].wallet2FAAddr, "Crypto2FAHook: invalid signature");
    }

    function preUserOpValidationHook(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds,
        bytes calldata hookSignature
    ) external view override {
        console.log("hookSignature");
        console.logBytes(hookSignature);
        (userOp, userOpHash, missingAccountFunds, hookSignature);
        address recoveredAddress = userOpHash.toEthSignedMessageHash().recover(hookSignature);
        require(recoveredAddress == user2FA[msg.sender].wallet2FAAddr, "Crypto2FAHook: invalid signature");
    }

    function initiateChange2FA(address new2FA) external {
        User2FA storage _user2fa = user2FA[msg.sender];
        require(_user2fa.initialized, "User not initialized");
        _user2fa.pending2FAAddr = new2FA;
        _user2fa.effectiveTime = block.timestamp + TIME_LOCK_DURATION;
    }

    function applyChange2FA() external {
        User2FA storage _user2fa = user2FA[msg.sender];
        require(block.timestamp >= _user2fa.effectiveTime, "Time lock not expired");
        _user2fa.wallet2FAAddr = _user2fa.pending2FAAddr;
        _user2fa.pending2FAAddr = address(0);
        _user2fa.effectiveTime = 0;
    }

    function cancelChange2FA() external {
        User2FA storage _user2fa = user2FA[msg.sender];
        require(block.timestamp < _user2fa.effectiveTime, "Change already effective");
        _user2fa.pending2FAAddr = address(0);
        _user2fa.effectiveTime = 0;
    }
}
