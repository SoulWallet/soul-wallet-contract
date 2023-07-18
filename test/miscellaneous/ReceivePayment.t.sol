// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@source/miscellaneous/ReceivePayment.sol";

contract ReceivePaymentTest is Test {
    ReceivePayment receivePayment;
    address fundReceiver;
    address owner;
    uint256 sendAmount;

    function setUp() public {
        owner = makeAddr("owner");
        fundReceiver = makeAddr("fundReceiver");
        receivePayment = new ReceivePayment(owner);
    }

    event PaymentReceived(bytes32 indexed paymentId, address indexed sender, uint256 amount);

    function test_receivePayment() public {
        fund();
    }

    function fund() private {
        address randomUser = makeAddr("randomUser");
        sendAmount = 0.1 ether;
        hoax(randomUser, 1 ether);
        bytes32 paymentId = keccak256(abi.encode(block.timestamp, randomUser, sendAmount));
        vm.expectEmit(address(receivePayment));
        // We emit the event we expect to see.
        emit PaymentReceived(paymentId, randomUser, sendAmount);
        receivePayment.pay{value: 0.1 ether}(paymentId);
        assertEq(address(receivePayment).balance, sendAmount);
    }

    function test_withdrawFund() public {
        fund();
        vm.prank(owner);
        uint256 beforeWithDrawBalance = fundReceiver.balance;
        receivePayment.withdraw(fundReceiver);
        uint256 AfterDrawBalance = fundReceiver.balance;
        assertEq(AfterDrawBalance - beforeWithDrawBalance, sendAmount);
        assertEq(address(receivePayment).balance, 0);
    }

    function test_withdrawFundNotOwner() public {
        fund();
        vm.prank(fundReceiver);
        vm.expectRevert();
        receivePayment.withdraw(fundReceiver);
    }
}
