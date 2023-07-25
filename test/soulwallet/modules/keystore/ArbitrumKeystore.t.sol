// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@source/modules/keystore/ArbitrumKeyStoreModule/ArbKnownStateRootWithHistory.sol";
import "@source/modules/keystore/ArbitrumKeyStoreModule/L1BlockInfoPassing.sol";
import {ArbitrumInboxMock} from "./ArbitrumInboxMock.sol";
import "./MockKeyStoreData.sol";

contract ArbKeystoreTest is Test, MockKeyStoreData {
    L1BlockInfoPassing l1Contract;
    ArbKnownStateRootWithHistory l2Contract;
    ArbitrumInboxMock inboxMock;
    address owner;

    function setUp() public {
        owner = makeAddr("owner");
        vm.deal(owner, 10 ether);
        vm.startPrank(owner);
        inboxMock = new ArbitrumInboxMock();
        l2Contract = new ArbKnownStateRootWithHistory(address(0), owner);
        l1Contract = new L1BlockInfoPassing(address(0), address(inboxMock), owner);
        l2Contract.updateL1Target(address(l1Contract));
        l1Contract.updateL2Target(address(l2Contract));
        vm.stopPrank();
        vm.roll(TEST_BLOCK_NUMBER);
    }

    function testL1ToL2Message() public {
        l1Contract.passBlockHashInL2{value: 1 ether}(0.1 ether, 1_000_000, 10 gwei);
    }

    function testMockSetHash() public {
        address l2Alias = AddressAliasHelper.applyL1ToL2Alias(address(l1Contract));
        vm.deal(l2Alias, 100 ether);
        vm.startPrank(l2Alias);
        l2Contract.setBlockHash(1, TEST_BLOCK_HASH);
        bytes memory blockInfoParameter = BLOCK_INFO_BYTES;
        l2Contract.insertNewStateRoot(1, blockInfoParameter);
    }
}
