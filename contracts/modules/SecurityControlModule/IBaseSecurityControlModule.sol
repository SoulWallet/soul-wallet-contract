// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

interface IBaseSecurityControlModule {
    error NotInitializedError();
    error NotOwnerError();
    error AlreadyQueuedError(bytes32 txId);
    error NotQueuedError(bytes32 txId);
    error TimestampNotPassedError(uint256 blockTimestmap, uint256 timestamp);
    error ExecuteError(bytes32 txId, address target, address sender, bytes data, bytes returnData);

    event Queue(bytes32 indexed txId, address indexed target, address sender, bytes data, uint256 timestamp);
    event Cancel(bytes32 indexed txId, address sender);
    event CancelAll(address indexed target, address sender);
    event Execute(bytes32 indexed txId, address indexed target, address sender, bytes data);

    struct Tx {
        address target;
        uint128 validAfter;
    }

    struct WalletConfig {
        uint128 seed;
        uint64 delay;
    }

    function getTxId(uint128 _seed, address _target, bytes calldata _data) external view returns (bytes32);

    function getWalletConfig(address _target) external view returns (WalletConfig memory);

    function queue(address _target, bytes calldata _data) external returns (bytes32);

    function cancel(bytes32 _txId) external;

    function cancelAll(address _target) external;

    function execute(address _target, bytes calldata _data) external;
}
