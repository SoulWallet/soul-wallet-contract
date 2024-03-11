// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "./DeployHelper.sol";
import "@source/automation/AaveUsdcSaveAutomation.sol";

contract AutomationDeployer is Script, DeployHelper {
    address automationOwner;
    uint256 automationOwnerPrivateKey;
    address soulwalletFactory;
    address automationBot;
    uint256 automationBotPrivateKey;

    function run() public {
        automationOwnerPrivateKey = vm.envUint("AUTOMATION_OWNER_PRIVATE_KEY");
        require(automationOwnerPrivateKey != 0, "AUTOMATION_OWNER_PRIVATE_KEY not provided");
        automationOwner = vm.addr(automationOwnerPrivateKey);
        automationBotPrivateKey = vm.envUint("AUTOMATION_BOT_PRIVATE_KEY");
        automationBot = vm.addr(automationBotPrivateKey);
        require(automationOwner != address(0), "AUTOMATION_OWNER_ADDRESS not provided");
        soulwalletFactory = vm.envAddress("SOULWALLET_FACTORY_ADDRESS");
        require(soulwalletFactory != address(0), "SOULWALLET_FACTORY_ADDRESS not provided");
        require(address(soulwalletFactory).code.length > 0, "soulwalletFactory needs be deployed");
        vm.startBroadcast(privateKey);

        Network network = getNetwork();
        if (network == Network.Sepolia) {
            console.log("deploy automation contract on Sepolia");
            // same logic as localtestnet
            delpoySepolia();
        } else if (network == Network.OptimismSepolia) {
            console.log("deploy automation contract on OptimismSepolia");
            delpoyOpSepolia();
        } else if (network == Network.ArbitrumSepolia) {
            console.log("deploy automation contract on ArbitrumSepolia");
            delpoyArbSepolia();
        } else {
            console.log("deploy automation contract on testnet");
            deploy();
        }
    }

    function deploy() private pure {
        revert("not implemented");
    }

    function delpoySepolia() private {
        address usdc = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8;
        address aaveUscPool = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
        address aUsdcToken = 0x16dA4541aD1807f4443d92D26044C1147406EB80;

        address aaveUsdcAutomation = deploy(
            "AaveUsdcSaveAutomationSepolia",
            bytes.concat(
                type(AaveUsdcSaveAutomation).creationCode, abi.encode(automationBot, usdc, aaveUscPool, aUsdcToken)
            )
        );
        writeAddressToEnv("SOUL_WALLET_AAVE_USDC_AUTOMATION_SEPOLIA", aaveUsdcAutomation);
    }

    function delpoyArbSepolia() private {
        address usdc = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d;
        address aaveUscPool = 0xBfC91D59fdAA134A4ED45f7B584cAf96D7792Eff;
        address aUsdcToken = 0x625E7708f30cA75bfd92586e17077590C60eb4cD;

        address aaveUsdcAutomation = deploy(
            "AaveUsdcSaveAutomationArbSepolia",
            bytes.concat(
                type(AaveUsdcSaveAutomation).creationCode, abi.encode(automationBot, usdc, aaveUscPool, aUsdcToken)
            )
        );
        writeAddressToEnv("SOUL_WALLET_AAVE_USDC_AUTOMATION_ARB_SEPOLIA", aaveUsdcAutomation);
    }

    function delpoyOpSepolia() private {
        address usdc = 0x5fd84259d66Cd46123540766Be93DFE6D43130D7;
        address aaveUscPool = 0xb50201558B00496A145fE76f7424749556E326D8;
        address aUsdcToken = 0xa818F1B57c201E092C4A2017A91815034326Efd1;

        address aaveUsdcAutomation = deploy(
            "AaveUsdcSaveAutomationOpSepolia",
            bytes.concat(
                type(AaveUsdcSaveAutomation).creationCode, abi.encode(automationBot, usdc, aaveUscPool, aUsdcToken)
            )
        );
        writeAddressToEnv("SOUL_WALLET_AAVE_USDC_AUTOMATION_OP_SEPOLIA", aaveUsdcAutomation);
    }
}
