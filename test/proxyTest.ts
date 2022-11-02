/*
 * @Description: 
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-10-24 10:00:34
 * @LastEditors: cejay
 * @LastEditTime: 2022-10-31 22:09:57
 */

import "hardhat-gas-reporter";
import { ethers, network, run } from "hardhat";

async function main() {

    // get account
    const accounts = await ethers.getSigners();
    const account = accounts[0];

    // deploy logic contract
    const SoulWalletLogicTestBefore = await (await ethers.getContractFactory("SoulWalletLogicTestBefore")).deploy();
    await SoulWalletLogicTestBefore.deployed();

    const SoulWalletLogicTestAfter = await (await ethers.getContractFactory("SoulWalletLogicTestAfter")).deploy();
    await SoulWalletLogicTestAfter.deployed();

    const SoulWalletLogicTest = await ethers.getContractAt("SoulWalletLogicTestBefore", SoulWalletLogicTestBefore.address);

    const initializeData = SoulWalletLogicTest.interface.encodeFunctionData("initialize", [account.address]);


    // #region new Proxy
    {
        // deploy proxy contract

        // get deploy gas cost
        const accountBalanceBefore = await ethers.provider.getBalance(account.address);
        const proxy = await ethers.getContractFactory("SoulWalletProxy");

        const ProxyContract = await proxy.deploy(
            SoulWalletLogicTestBefore.address, initializeData
        );
        await ProxyContract.deployed();

        const accountBalanceAfter = await ethers.provider.getBalance(account.address);
        // cost = (accountBalanceBefore - accountBalanceAfter) / gasPrice
        const gasPrice = await ethers.provider.getGasPrice();
        const gasCost = accountBalanceBefore.sub(accountBalanceAfter).div(gasPrice);
        console.log("NEW - gasCost: ", gasCost.toString(), "bytecodeLen:", proxy.bytecode.length, "gasPrice: ", gasPrice.toString());

        // test upgrade

        // call getLogicInfo function
        // load contract at proxy address
        const contract_before = await ethers.getContractAt("SoulWalletLogicTestBefore", ProxyContract.address);
        const logicInfo = await contract_before.getLogicInfo();
        if (logicInfo != 'SoulWalletLogicTestBefore') {
            throw new Error("logicInfo error");
        }
        
        try {
            await contract_before.upgradeTo(SoulWalletLogicTestAfter.address);
            throw new Error("upgradeTo should fail");
        } catch (error) {
        }
        // setAllowedUpgrade
        await contract_before.setAllowedUpgrade(SoulWalletLogicTestAfter.address);
        try {
            await contract_before.upgradeTo(SoulWalletLogicTestAfter.address);
        } catch (error) {
            throw new Error("upgradeTo should success");
        }
        const logicInfo2 = await contract_before.getLogicInfo();
        if (logicInfo2 != 'SoulWalletLogicTestAfter') {
            throw new Error("logicInfo error");
        }
    }
    // #endregion

    // #region old Proxy
    {
        // deploy proxy contract
        // get deploy gas cost
        const accountBalanceBefore = await ethers.provider.getBalance(account.address);
        const proxy = await ethers.getContractFactory("WalletProxy");
        const ProxyContract = await proxy.deploy(
            SoulWalletLogicTestBefore.address, initializeData
        );
        await ProxyContract.deployed();

        const accountBalanceAfter = await ethers.provider.getBalance(account.address);
        // cost = (accountBalanceBefore - accountBalanceAfter) / gasPrice
        const gasPrice = await ethers.provider.getGasPrice();
        const gasCost = accountBalanceBefore.sub(accountBalanceAfter).div(gasPrice);
        console.log("OLD - gasCost: ", gasCost.toString(), "bytecodeLen:", proxy.bytecode.length, "gasPrice: ", gasPrice.toString());

    }
    // #endregion




}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
