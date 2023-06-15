// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../BaseModule.sol";
import "./IBaseSecurityControlModule.sol";
import "../../trustedContractManager/ITrustedContractManager.sol";

// refer to: https://solidity-by-example.org/app/time-lock/

abstract contract BaseSecurityControlModule is IBaseSecurityControlModule, BaseModule {
    uint256 public constant MIN_DELAY = 1 days;
    uint256 public constant MAX_DELAY = 14 days;

    mapping(bytes32 => Tx) private queued;
    mapping(address => WalletConfig) private walletConfigs;

    uint128 private __seed;

    function _newSeed() private returns (uint128) {
        return ++__seed;
    }

    function _authorized(address _target) private view {
        address _sender = sender();
        if (_sender != _target && !ISoulWallet(_target).isOwner(_sender)) {
            revert NotOwnerError();
        }
        if (walletConfigs[_target].seed == 0) {
            revert NotInitializedError();
        }
    }

    function inited(address _target) internal view override returns (bool) {
        return walletConfigs[_target].seed != 0;
    }

    function _init(bytes calldata data) internal override {
        uint64 _delay = abi.decode(data, (uint64));
        require(_delay >= MIN_DELAY && _delay <= MAX_DELAY);
        address _target = sender();
        walletConfigs[_target] = WalletConfig(_newSeed(), _delay);
    }

    function _deInit() internal override {
        address _target = sender();
        walletConfigs[_target] = WalletConfig(0, 0);
    }

    function _getTxId(uint128 _seed, address _target, bytes calldata _data) private view returns (bytes32) {
        return keccak256(abi.encode(block.chainid, address(this), _seed, _target, _data));
    }

    function getTxId(uint128 _seed, address _target, bytes calldata _data) public view override returns (bytes32) {
        return _getTxId(_seed, _target, _data);
    }

    function getWalletConfig(address _target) external view override returns (WalletConfig memory) {
        return walletConfigs[_target];
    }

    function queue(address _target, bytes calldata _data) external virtual override returns (bytes32 txId) {
        _authorized(_target);
        WalletConfig memory walletConfig = walletConfigs[_target];
        txId = _getTxId(walletConfig.seed, _target, _data);
        if (queued[txId].target != address(0)) {
            revert AlreadyQueuedError(txId);
        }
        uint256 _timestamp = block.timestamp + walletConfig.delay;
        queued[txId] = Tx(_target, uint128(_timestamp));
        emit Queue(txId, _target, sender(), _data, _timestamp);
    }

    function cancel(bytes32 _txId) external virtual override {
        Tx memory _tx = queued[_txId];
        if (_tx.target == address(0)) {
            revert NotQueuedError(_txId);
        }
        _authorized(_tx.target);

        queued[_txId] = Tx(address(0), 0);
        emit Cancel(_txId, sender());
    }

    function cancelAll(address target) external virtual override {
        _authorized(target);
        address _sender = sender();
        walletConfigs[target].seed = _newSeed();
        emit CancelAll(target, _sender);
    }

    function _preExecute(address _target, bytes calldata _data, bytes32 _txId) internal virtual {
        (_target, _data);
        Tx memory _tx = queued[_txId];
        uint256 validAfter = _tx.validAfter;
        if (validAfter == 0) {
            revert NotQueuedError(_txId);
        }
        if (block.timestamp < validAfter) {
            revert TimestampNotPassedError(block.timestamp, validAfter);
        }
        queued[_txId] = Tx(address(0), 0);
    }

    function execute(address _target, bytes calldata _data) external virtual override {
        _authorized(_target);
        WalletConfig memory walletConfig = walletConfigs[_target];
        bytes32 txId = _getTxId(walletConfig.seed, _target, _data);
        _preExecute(_target, _data, txId);
        (bool succ, bytes memory ret) = _target.call{value: 0}(_data);
        if (succ) {
            emit Execute(txId, _target, sender(), _data);
        } else {
            revert ExecuteError(txId, _target, sender(), _data, ret);
        }
    }
}
