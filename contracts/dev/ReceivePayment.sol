// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract ReceivePayment is Ownable {
    event PaymentReceived(bytes32 indexed paymentId, address indexed sender, uint256 amount);

    constructor(address _owner) Ownable(_owner) {}
    // just emit event id with payment id generated by backend
    // there is no need to add logic in contract to validate payment id
    // it is handled by backend

    function pay(bytes32 _paymentId) external payable {
        emit PaymentReceived(_paymentId, msg.sender, msg.value);
    }

    function withdraw(address _to) external onlyOwner {
        (bool success,) = payable(_to).call{value: address(this).balance}("");
        require(success, "Withdraw failed");
    }
}
