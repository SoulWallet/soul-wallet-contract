// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;
import "../BaseModule.sol";

// refer to: https://solidity-by-example.org/app/time-lock/

// TODO: what about wallet add and remove SecurityControlModule

// 1. add timelock to trx
// 2. trx must be executed in sequence
// 3. all trx must be either executed or cancled
contract SecurityControlModule is BaseModule {
    uint public constant MIN_DELAY = 1 days;
    uint public constant MAX_DELAY = 14 days;
    uint public constant GRACE_PERIOD = 30 days;

    struct WalletConfig {
        bool inited;
        uint64 allocNonce;
        uint64 execNonce;
        uint64 delay;
    }

    mapping(bytes32 => uint256) private validAfter;
    mapping(address => WalletConfig) private walletConfigs;

    modifier authorized(address _target) {
        address _sender = sender();
        require(_sender == _target || ISoulWallet(_target).isOwner(_sender));
        require(walletConfigs[_target].inited);
        // TODO: require wallet is not locked
        _;
    }


    function inited(address wallet) internal view override returns (bool) {
        return walletConfigs[wallet].inited;
    }

    function _init(bytes calldata data) internal override {
        uint64 _delay = abi.decode(data, (uint64));
        require(_delay >= MIN_DELAY && _delay <= MAX_DELAY);
        address _sender = sender();
        walletConfigs[_sender].inited = true;
        walletConfigs[_sender].delay = _delay;
    }

    function _deInit() internal override {
        address _sender = sender();
        walletConfigs[_sender].inited = false;
        walletConfigs[_sender].delay = 0;
        // cancel all pending trx
        for (uint64 i = walletConfigs[_sender].execNonce; i < walletConfigs[_sender].allocNonce; i++) {
            validateAndUpdateExecNonce(_sender, i);
        }
    }

    function validateAndUpdateAllocNonce(address wallet, uint64 nonce) private {
        require(walletConfigs[wallet].allocNonce++ == nonce);
    }

    function validateAndUpdateExecNonce(address wallet, uint64 nonce) private {
        require(walletConfigs[wallet].execNonce < walletConfigs[wallet].allocNonce);
        require(walletConfigs[wallet].execNonce++ == nonce);
    }

    function getTxId(
        address _target,
        bytes4 _func,
        bytes calldata _data,
        uint64 nonce
    ) public returns (bytes32) {
        return keccak256(abi.encode(block.chainid, address(this), nonce, _target, _func, _data));
    }

    function getWalletConfig(address _target) public view returns (WalletConfig memory) {
        return walletConfigs[_target];
    }

    function queue(
        address _target,
        bytes4 _func,
        bytes calldata _data,
        uint64 nonce
    ) public authorized(_target) returns (bytes32 txId) {
        validateAndUpdateAllocNonce(_target, nonce);
        // TODO: require _func in list
        // TODO: if in whitelist, execute without delay
        txId = getTxId(_target, _func, _data, nonce);
        // require(validAfter[txId] == 0);
        validAfter[txId] = block.timestamp + walletConfigs[_target].delay;
    }

    // TOOD: batch cancel or clear all pending trx, which
    // is useful after social recovery
    function cancel(
        address _target,
        uint64 nonce
    ) public authorized(_target) {
        validateAndUpdateExecNonce(_target, nonce);
    }

    function execute(
        address _target,
        bytes4 _func,
        bytes calldata _data,
        uint64 nonce
    ) public authorized(_target) returns (bytes32 txId) {
        validateAndUpdateExecNonce(_target, nonce);
        txId = getTxId(_target, _func, _data, nonce);
        require(block.timestamp > validAfter[txId]);
        require(block.timestamp <= validAfter[txId] + GRACE_PERIOD);

        bytes memory data = abi.encodePacked(_func, _data);
        (bool ok, bytes memory res) = _target.call{value: 0}(data);
        require(ok);
    }
}