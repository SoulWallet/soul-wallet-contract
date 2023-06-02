// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;
import "../safeLock/SafeLock.sol";

contract SafeLockHelper is SafeLock {
    constructor(uint64 safeLockPeriod) SafeLock("SafeLockHelper", safeLockPeriod) {}

    function start(bytes32 _id) external {
        _lock(_id);
    }

    function cancel(bytes32 _id) external {
        _cancelLock(_id);
    }

    function end(bytes32 _id) external {
        _unlock(_id);
    }
}
