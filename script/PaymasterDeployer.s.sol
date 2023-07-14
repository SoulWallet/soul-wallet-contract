// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@account-abstraction/contracts/core/EntryPoint.sol";
import "@source/dev/Tokens/TokenERC20.sol";
import "@source/dev/TestOracle.sol";
import "./DeployHelper.sol";
import "@source/paymaster/ERC20Paymaster.sol";

contract PaymasterDeployer is Script, DeployHelper {
    address paymasterOwner;
    uint256 paymasterOwnerPrivateKey;
    address soulwalletFactory;

    function run() public {
        paymasterOwnerPrivateKey = vm.envUint("PAYMASTER_OWNER_PRIVATE_KEY");
        require(paymasterOwnerPrivateKey != 0, "PAYMASTER_OWNER_PRIVATE_KEY not provided");
        paymasterOwner = vm.addr(paymasterOwnerPrivateKey);
        require(paymasterOwner != address(0), "PAYMASTER_OWNER_ADDRESS not provided");
        soulwalletFactory = vm.envAddress("SOUL_WALLET_FACTORY");
        require(soulwalletFactory != address(0), "SOUL_WALLET_FACTORY not provided");
        require(address(soulwalletFactory).code.length > 0, "soulwalletFactory needs be deployed");
        vm.startBroadcast(privateKey);

        Network network = getNetwork();
        if (network == Network.Mainnet) {
            console.log("deploy paymaster contract on mainnet");
            deploy();
        } else if (network == Network.Goerli) {
            console.log("deploy keystore contract on Goerli");
            // same logic as localtestnet
            delpoyLocal();
        } else if (network == Network.Arbitrum) {
            console.log("deploy paymaster contract on Arbitrum");
            deploy();
        } else if (network == Network.Optimism) {
            console.log("deploy paymaster contract on Optimism");
            deploy();
        } else if (network == Network.Anvil) {
            console.log("deploy paymaster contract on Anvil");
            deploySingletonFactory();
            delpoylocalEntryPoint();
            delpoyLocal();
        } else if (network == Network.OptimismGoerli) {
            console.log("deploy soul wallet contract on OptimismGoerli");
            delpoyLocal();
        } else {
            console.log("deploy paymaster contract on testnet");
            deploy();
        }
    }

    function deploy() private {
        revert("not implemented");
    }

    function delpoyLocal() private {
        address testUsdc = deploy("TestUsdc", bytes.concat(type(TokenERC20).creationCode, abi.encode(6)));
        address testOracle = deploy("TestOracle", bytes.concat(type(TestOracle).creationCode, abi.encode(190355094900)));
        address paymaster = deploy(
            "Paymaster",
            bytes.concat(
                type(ERC20Paymaster).creationCode, abi.encode(ENTRYPOINT_ADDRESS, paymasterOwner, soulwalletFactory)
            )
        );
        address[] memory tokens = new address[](1);
        tokens[0] = testUsdc;
        address[] memory oracles = new address[](1);
        oracles[0] = testOracle;
        uint32[] memory priceMarkups = new uint32[](1);
        priceMarkups[0] = 1e6;

        vm.stopBroadcast();
        // start broadcast using  paymasterOwner
        vm.startBroadcast(paymasterOwnerPrivateKey);
        ERC20Paymaster(paymaster).setToken(tokens, oracles, priceMarkups);
    }

    function delpoylocalEntryPoint() private {
        ENTRYPOINT_ADDRESS = deploy("EntryPoint", type(EntryPoint).creationCode);
    }
}
