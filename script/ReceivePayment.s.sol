// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "./DeployHelper.sol";
import "@source/dev/ReceivePayment.sol";

contract ReceivePaymentDeployer is Script, DeployHelper {
    address paymasterOwner;
    uint256 paymasterOwnerPrivateKey;
    address soulwalletFactory;

    function run() public {
        vm.startBroadcast(privateKey);
        deploy();
    }

    function deploy() private {
        address receivePaymentOwner = vm.envAddress("RECEIVE_PAYMENT_OWNER_ADDRESS");
        deploy("ReceivePayment", bytes.concat(type(ReceivePayment).creationCode, abi.encode(receivePaymentOwner)));
    }
}
