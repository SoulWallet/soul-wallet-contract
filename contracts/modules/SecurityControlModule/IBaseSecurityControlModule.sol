// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

interface IBaseSecurityControlModule {
    error NotInitializedError();
    error NotOwnerError();
    error AlreadyQueuedError(bytes32 txId);
    error NotQueuedError(bytes32 txId);
    error TimestampNotPassedError(uint256 blockTimestmap, uint256 timestamp);

    event Queue(address indexed sender, bytes32 indexed txId, address target, bytes data, uint256 timestamp);
    event Execute(bool indexed success, address indexed sender, bytes32 indexed txId, address target, bytes data);
    event Cancel(address indexed sender, bytes32 indexed txId);
    event CancelAll(address indexed sender);

    struct Tx {
        address target;
        uint128 validAfter;
    }

    struct WalletConfig {
        uint128 inited;
        uint64 delay;
    }

    function getTxId(uint128 _seed, address _target, bytes calldata _data) external view returns (bytes32);

    function getWalletConfig(address _target) external view returns (WalletConfig memory);

    function queue(address _target, bytes calldata _data) external returns (bytes32);

    function cancel(bytes32 _txId) external;

    function cancelAll() external;

    function execute(address _target, bytes calldata _data) external returns (bool, bytes memory);
}
