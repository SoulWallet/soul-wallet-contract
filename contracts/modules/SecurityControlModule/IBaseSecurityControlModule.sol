// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

interface IBaseSecurityControlModule {
    error NotInitializedError();
    error NotOwnerError();
    error AlreadyQueuedError(bytes32 txId);
    error NotQueuedError(bytes32 txId);
    error TimestampNotPassedError(uint blockTimestmap, uint timestamp);

    event Queue(
        bytes32 indexed txId,
        address indexed target,
        bytes data,
        uint timestamp
    );
    event Execute(
        bool indexed success,
        bytes32 indexed txId,
        address indexed target,
        bytes data
    );
    event Cancel(bytes32 indexed txId);

    struct Tx {
        address target;
        uint128 validAfter;
    }

    struct WalletConfig {
        uint128 inited;
        uint64 delay;
    }

    function getTxId(
        uint128 _seed,
        address _target,
        bytes calldata _data
    ) external returns (bytes32);

    function getWalletConfig(
        address _target
    ) external view returns (WalletConfig memory);

    function queue(
        address _target,
        bytes calldata _data
    ) external returns (bytes32);

    function cancel(bytes32 _txId) external;

    function execute(
        address _target,
        bytes calldata _data
    ) external returns (bool, bytes memory);
}
