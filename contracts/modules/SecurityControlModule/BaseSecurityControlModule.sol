// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;
import "../BaseModule.sol";
import "./IBaseSecurityControlModule.sol";
import "../../trustedContractManager/ITrustedContractManager.sol";

// refer to: https://solidity-by-example.org/app/time-lock/

abstract contract BaseSecurityControlModule is IBaseSecurityControlModule, BaseModule {
    uint public constant MIN_DELAY = 1 days;
    uint public constant MAX_DELAY = 14 days;

    mapping(bytes32 => Tx) private queued;
    mapping(address => WalletConfig) private walletConfigs;

    uint128 private __seed = 0;

    function newSeed() private returns (uint128) {
        __seed++;
        return __seed;
    }

    function authorized(address _target) private view {
        address _sender = sender();
        if (_sender != _target && !ISoulWallet(_target).isOwner(_sender)) {
            revert NotOwnerError();
        }
        if (walletConfigs[_target].inited == 0) {
            revert NotInitializedError();
        }
        // TODO: require wallet is not locked
    }

    function inited(address wallet) internal view override returns (bool) {
        return walletConfigs[wallet].inited != 0;
    }

    function _init(bytes calldata data) internal override {
        uint64 _delay = abi.decode(data, (uint64));
        require(_delay >= MIN_DELAY && _delay <= MAX_DELAY);
        address _sender = sender();
        walletConfigs[_sender] = WalletConfig(newSeed(), _delay);
    }

    function _deInit() internal override {
        address _sender = sender();
        walletConfigs[_sender] = WalletConfig(0, 0);
    }

    function getTxId(
        uint128 _seed,
        address _target,
        bytes calldata _data
    ) public override returns (bytes32) {
        return
            keccak256(
                abi.encode(block.chainid, address(this), _seed, _target, _data)
            );
    }

    function getWalletConfig(
        address _target
    ) external view override returns (WalletConfig memory) {
        return walletConfigs[_target];
    }

    function queue(
        address _target,
        bytes calldata _data
    ) external virtual override returns (bytes32 txId) {
        authorized(_target);
        WalletConfig memory walletConfig = walletConfigs[_target];
        txId = getTxId(walletConfig.inited, _target, _data);
        if (queued[txId].target != address(0)) {
            revert AlreadyQueuedError(txId);
        }
        uint256 _timestamp = block.timestamp + walletConfig.delay;
        queued[txId] = Tx(_target, uint128(_timestamp));
        emit Queue(txId, _target, _data, _timestamp);
    }

    // TOOD: batch cancel or clear all pending trx, which
    // is useful after social recovery
    function cancel(bytes32 _txId) external virtual override {
        Tx memory _tx = queued[_txId];
        if (_tx.target == address(0)) {
            revert NotQueuedError(_txId);
        }
        authorized(_tx.target);

        queued[_txId] = Tx(address(0), 0);
        emit Cancel(_txId);
    }

    function preExecute(
        address _target,
        bytes calldata _data,
        bytes32 _txId
    ) internal virtual {
        (_target, _data);
        Tx memory _tx = queued[_txId];
        uint256 validAfter = _tx.validAfter;
        if (validAfter == 0) {
            revert NotQueuedError(_txId);
        }
        if (block.timestamp < validAfter) {
            revert TimestampNotPassedError(block.timestamp, validAfter);
        }
    }

    function execute(
        address _target,
        bytes calldata _data
    ) external virtual override returns (bool, bytes memory) {
        authorized(_target);
        WalletConfig memory walletConfig = walletConfigs[_target];
        bytes32 txId = getTxId(walletConfig.inited, _target, _data);
        preExecute(_target, _data, txId);
        queued[txId] = Tx(address(0), 0);
        // call target
        (bool ok, bytes memory res) = _target.call{value: 0}(_data);
        emit Execute(ok, txId, _target, _data);
        return (ok, res);
    }

}
