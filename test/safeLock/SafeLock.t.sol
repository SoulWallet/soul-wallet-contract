// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@source/dev/SafeLockHelper.sol";

contract SafeLockTest is Test {
    SafeLockHelper public safeLockHelper;

    function setUp() public {
        safeLockHelper = new SafeLockHelper(2 days);
    }

    function test_lock1() public {
        bytes32 id = keccak256("test_lock");
        safeLockHelper.start(id);
        vm.expectRevert(bytes("SafeLock: already locked"));
        safeLockHelper.start(id);
    }

    function test_lock2() public {
        bytes32 id = keccak256("test_lock");
        safeLockHelper.start(id);
        safeLockHelper.cancel(id);
    }

    function test_lock3() public {
        bytes32 id = keccak256("test_lock");
        vm.expectRevert(bytes("SafeLock: not unlock time"));
        safeLockHelper.end(id);
    }

    function test_lock4() public {
        uint256 _now = block.timestamp;
        bytes32 id = keccak256("test_lock");
        safeLockHelper.start(id);
        vm.expectRevert(bytes("SafeLock: not unlock time"));
        safeLockHelper.end(id);
        // 1 days later
        vm.warp(_now + 1 days);
        vm.expectRevert(bytes("SafeLock: not unlock time"));
        safeLockHelper.end(id);
        // 2 days later
        vm.warp(_now + 2 days);
        safeLockHelper.end(id);
    }

    function test_lock5() public {
        uint256 _now = block.timestamp;
        bytes32 id = keccak256("test_lock");
        safeLockHelper.start(id);
        safeLockHelper.cancel(id);
        // 2 days later
        vm.warp(_now + 2 days);
        vm.expectRevert(bytes("SafeLock: not unlock time"));
        safeLockHelper.end(id);
    }
}
