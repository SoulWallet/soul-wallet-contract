/*
 * @Description: 
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-10-03 23:30:41
 * @LastEditors: cejay
 * @LastEditTime: 2022-10-04 00:40:26
 */


import { ethers, network, run } from "hardhat";

async function main() {

    const WETH = '0x2787015262404f11d7B6920C7eB46e25595e2Bf5';

    const create2factory = "0xce0042B868300000d44A59004Da54A005ffdcf9f";
    const paymasterStake = Math.pow(10, 17) + ''; // POC testNet 0.1 ETH
    // #region EntryPoint
    const unstakeDelaySec = 100;

    const entryPointContract = await (await ethers.getContractFactory("EntryPoint")).deploy(create2factory, paymasterStake, unstakeDelaySec);

    await entryPointContract.deployed();

    console.log("entryPoint:", entryPointContract.address);
    // verify 
    if (network.name !== "hardhat") {
        try {
            await run("verify:verify", {
                address: entryPointContract.address,
                constructorArguments: [create2factory, paymasterStake, unstakeDelaySec],
            });
        } catch (error) {
            console.log("entryPointContract verify failed:", error);
        }
    }

    // #endregion


    // #region WETHPaymaster

    //  constructor(EntryPoint _entryPoint,address _owner, IERC20 _WETHToken)
    const [owner] = await ethers.getSigners();
    const WETHPaymasterContract = await (await ethers.getContractFactory("WETHTokenPaymaster")).deploy(entryPointContract.address, owner.address, WETH);
    await WETHPaymasterContract.deployed();
    console.log("WETHPaymaster:", WETHPaymasterContract.address);
    // verify
    if (network.name !== "hardhat") {
        try {
            await run("verify:verify", {
                address: WETHPaymasterContract.address,
                constructorArguments: [entryPointContract.address, owner.address, WETH],
            });
        } catch (error) {
            console.log("WETHPaymasterContract verify failed:", error);
        }
    }


    // #endregion


}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
