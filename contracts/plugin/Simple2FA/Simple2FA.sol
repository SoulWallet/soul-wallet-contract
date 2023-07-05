// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../BasePlugin.sol";
import "./ISimple2FA.sol";
import "../../safeLock/SafeLock.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../../base/ExecutionManager.sol";
import "../../libraries/DecodeCalldata.sol";

contract Simple2FA is BasePlugin, ISimple2FA, SafeLock {
    using ECDSA for bytes32;

    struct User2FA {
        bool initialized;
        address _2FAAddr;
    }

    mapping(address => User2FA) private _2FA;

    constructor() SafeLock("PLUGIN_SIMPLE2FA_SAFELOCK_SLOT", 2 days) {}

    function preHook(address target, uint256 value, bytes calldata data) external pure override {
        (target, value, data);
        revert("Simple2FA: no need to call preHook");
    }

    function postHook(address target, uint256 value, bytes calldata data) external pure override {
        (target, value, data);
        revert("Simple2FA: no need to call postHook");
    }

    function guardHook(UserOperation calldata userOp, bytes32 userOpHash, bytes calldata guardData)
        external
        view
        override
    {
        (userOp);
        address _2FAAddr = _2FA[msg.sender]._2FAAddr;
        if (_2FAAddr != address(0)) {
            if (guardData.length == 0) {
                // # 1. function execute(address dest, uint256 value, bytes calldata func)
                // userOp.callData;
                bytes4 selector = bytes4(userOp.callData[0:4]);
                require(selector == ExecutionManager.execute.selector, "Simple2FA: invalid selector");
                // decode callData
                (address dest,, bytes memory func) = abi.decode(userOp.callData[4:], (address, uint256, bytes));
                // check dest
                require(dest == address(this), "Simple2FA: invalid dest");

                // # 2. preReset2FA or comfirmReset2FA
                // check func
                selector = DecodeCalldata.decodeMethodId(func);
                require(
                    selector == this.preReset2FA.selector || selector == this.comfirmReset2FA.selector,
                    "Simple2FA: invalid selector"
                );
            } else {
                // check signature
                bytes32 hash = userOpHash.toEthSignedMessageHash();
                (address recovered, ECDSA.RecoverError error) = ECDSA.tryRecover(hash, guardData);
                if (error != ECDSA.RecoverError.NoError) {
                    revert("Simple2FA: invalid signature");
                } else {
                    require(recovered == _2FAAddr, "Simple2FA: invalid signature");
                }
            }
        } else {
            // 2FA not set, skip
            require(guardData.length == 0, "Simple2FA: invalid signature");
        }
    }

    function _init(bytes calldata data) internal virtual override {
        (address _2FAAddr) = abi.decode(data, (address));
        _2FA[msg.sender] = User2FA({initialized: true, _2FAAddr: _2FAAddr});
    }

    function _deInit() internal virtual override {
        delete _2FA[msg.sender];
    }

    function _supportsHook() internal pure virtual override returns (uint8 hookType) {
        return GUARD_HOOK;
    }

    function inited(address wallet) internal view virtual override returns (bool) {
        return _2FA[wallet].initialized;
    }

    function reset2FA(address new2FA) external override {
        _2FA[msg.sender]._2FAAddr = new2FA;
    }

    function preReset2FA(address new2FA) external override {
        bytes32 hash = keccak256(abi.encode(msg.sender, new2FA));
        _lock(hash);
    }

    function comfirmReset2FA(address new2FA) external override {
        bytes32 hash = keccak256(abi.encode(msg.sender, new2FA));
        _unlock(hash);
        _2FA[msg.sender]._2FAAddr = new2FA;
    }

    function signerAddress(address addr) external view override returns (address) {
        return _2FA[addr]._2FAAddr;
    }
}
