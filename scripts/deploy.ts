/*
 * @Description: 
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-12-26 23:06:27
 * @LastEditors: cejay
 * @LastEditTime: 2022-12-27 21:30:07
 */

import { BigNumber } from "ethers";
import { getCreate2Address, hexlify, hexZeroPad, keccak256 } from "ethers/lib/utils";
import { ethers, network, run } from "hardhat";
import { EIP4337Lib, UserOperation } from 'soul-wallet-lib';
import { WETH9__factory, WETHTokenPaymaster__factory, Create2Factory__factory, EntryPoint__factory } from "../src/types/index";
import { Utils } from "./Utils";
import * as ethUtil from 'ethereumjs-util';


async function main() {

    // npx hardhat run --network goerli scripts/deploy.ts

    let create2Factory = '';
    let WETHContractAddress = '';

    if (network.name === "mainnet") {
        create2Factory = "0xce0042B868300000d44A59004Da54A005ffdcf9f";
        WETHContractAddress = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
    } else if (network.name === "goerli") {
        create2Factory = "0xce0042B868300000d44A59004Da54A005ffdcf9f";
        WETHContractAddress = '0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6';
    }
    if (!create2Factory) {
        throw new Error("create2Factory not set");
    }
    if (!WETHContractAddress) {
        throw new Error("WETHContractAddress not set");
    }

    const chainId = await (await ethers.provider.getNetwork()).chainId;

    const EOA = await ethers.getSigner('0x00000000000d3b4EA88f9B3fE809D386B86F5898');

    const walletOwner = '0x93EDb58cFc5d77028C138e47Fffb929A57C52082';
    const walletOwnerPrivateKey = '0x82cfe73c005926089ebf7ec1f49852207e5670870d0dfa544caabb83d2cd2d5f';


    const salt = hexZeroPad(hexlify(0), 32);

    // #region Entrypoint 

    const EntryPointFactory = await ethers.getContractFactory("EntryPoint");
    // get EntryPointFactory deployed bytecode
    const EntryPointFactoryBytecode = EntryPointFactory.bytecode;
    // get create2 address
    const EntryPointInitCodeHash = keccak256(EntryPointFactoryBytecode);
    const EntryPointAddress = getCreate2Address(create2Factory, salt, EntryPointInitCodeHash);
    console.log("EntryPointAddress:", EntryPointAddress);
    // if not deployed, deploy
    if (await ethers.provider.getCode(EntryPointAddress) === '0x') {
        console.log("EntryPoint not deployed, deploying...");
        const increaseGasLimit = (estimatedGasLimit: BigNumber) => {
            return ethers.BigNumber.from(Math.pow(10, 7) + '');
            //return estimatedGasLimit.mul(10)  // 10x gas
        }
        const create2FactoryContract = Create2Factory__factory.connect(create2Factory, EOA);
        const estimatedGas = await create2FactoryContract.estimateGas.deploy(EntryPointFactoryBytecode, salt);
        const tx = await create2FactoryContract.deploy(EntryPointFactoryBytecode, salt, { gasLimit: increaseGasLimit(estimatedGas) })
        console.log("EntryPoint tx:", tx.hash);
        while (await ethers.provider.getCode(EntryPointAddress) === '0x') {
            console.log("EntryPoint not deployed, waiting...");
            await new Promise(r => setTimeout(r, 3000));
        }
        console.log("EntryPoint deployed, verifying...");
        try {
            await run("verify:verify", {
                address: EntryPointAddress,
                constructorArguments: [],
            });
        } catch (error) {
            console.log("EntryPoint verify failed:", error);
        }
    } else {
    }

    // #endregion Entrypoint

    // #region WETHPaymaster 

    const WETHTokenPaymasterFactory = await ethers.getContractFactory("WETHTokenPaymaster");
    const WETHTokenPaymasterBytecode = WETHTokenPaymasterFactory.getDeployTransaction(EntryPointAddress, WETHContractAddress, EOA.address).data;
    if (!WETHTokenPaymasterBytecode) {
        throw new Error("WETHTokenPaymasterBytecode not set");
    }
    const WETHTokenPaymasterInitCodeHash = keccak256(WETHTokenPaymasterBytecode);
    const WETHTokenPaymasterAddress = getCreate2Address(create2Factory, salt, WETHTokenPaymasterInitCodeHash);
    console.log("WETHTokenPaymasterAddress:", WETHTokenPaymasterAddress);
    // if not deployed, deploy
    if (await ethers.provider.getCode(WETHTokenPaymasterAddress) === '0x') {
        console.log("WETHTokenPaymaster not deployed, deploying...");
        const increaseGasLimit = (estimatedGasLimit: BigNumber) => {
            return ethers.BigNumber.from(Math.pow(10, 7) + '');
            //return estimatedGasLimit.mul(10)  // 10x gas
        }
        const create2FactoryContract = Create2Factory__factory.connect(create2Factory, EOA);
        const estimatedGas = await create2FactoryContract.estimateGas.deploy(WETHTokenPaymasterBytecode, salt);
        const tx = await create2FactoryContract.deploy(WETHTokenPaymasterBytecode, salt, { gasLimit: increaseGasLimit(estimatedGas) })
        console.log("EntryPoint tx:", tx.hash);
        while (await ethers.provider.getCode(WETHTokenPaymasterAddress) === '0x') {
            console.log("WETHTokenPaymaster not deployed, waiting...");
            await new Promise(r => setTimeout(r, 3000));
        }
        const _paymasterStake = '' + Math.pow(10, 17);
        const WETHPaymaster = await WETHTokenPaymaster__factory.connect(WETHTokenPaymasterAddress, EOA);
        console.log(await WETHPaymaster.owner());
        console.log('adding stake');
        await WETHPaymaster.addStake(
            1, {
            from: EOA.address,
            value: _paymasterStake
        });
        await WETHPaymaster.deposit({
            from: EOA.address,
            value: _paymasterStake
        });
        console.log("WETHTokenPaymaster deployed, verifying...");
        try {
            await run("verify:verify", {
                address: WETHTokenPaymasterAddress,
                constructorArguments: [
                    EntryPointAddress, WETHContractAddress
                ],
            });
        } catch (error) {
            console.log("WETHTokenPaymaster verify failed:", error);
        }
    } else {

    }

    // #endregion WETHPaymaster

    // #region WalletLogic 

    const WalletLogicFactory = await ethers.getContractFactory("SmartWallet");
    const WalletLogicBytecode = WalletLogicFactory.bytecode;
    const WalletLogicInitCodeHash = keccak256(WalletLogicBytecode);
    const WalletLogicAddress = getCreate2Address(create2Factory, salt, WalletLogicInitCodeHash);
    console.log("WalletLogicAddress:", WalletLogicAddress);
    // if not deployed, deploy
    if (await ethers.provider.getCode(WalletLogicAddress) === '0x') {
        console.log("WalletLogic not deployed, deploying...");
        const increaseGasLimit = (estimatedGasLimit: BigNumber) => {
            return ethers.BigNumber.from(Math.pow(10, 7) + '');
            //return estimatedGasLimit.mul(10)  // 10x gas
        }
        const create2FactoryContract = Create2Factory__factory.connect(create2Factory, EOA);
        const estimatedGas = await create2FactoryContract.estimateGas.deploy(WalletLogicBytecode, salt);
        const tx = await create2FactoryContract.deploy(WalletLogicBytecode, salt, { gasLimit: increaseGasLimit(estimatedGas) })
        console.log("WalletLogic tx:", tx.hash);
        while (await ethers.provider.getCode(WalletLogicAddress) === '0x') {
            console.log("WalletLogic not deployed, waiting...");
            await new Promise(r => setTimeout(r, 3000));
        }
        console.log("WalletLogic deployed, verifying...");
        try {
            await run("verify:verify", {
                address: WalletLogicAddress,
                constructorArguments: [],
            });
        } catch (error) {
            console.log("WalletLogic verify failed:", error);
        }
    } else {
    }

    // #endregion WalletLogic

    // #region GuardianLogic 

    const GuardianLogicFactory = await ethers.getContractFactory("GuardianMultiSigWallet");
    const GuardianLogicBytecode = GuardianLogicFactory.bytecode;
    const GuardianLogicInitCodeHash = keccak256(GuardianLogicBytecode);
    const GuardianLogicAddress = getCreate2Address(create2Factory, salt, GuardianLogicInitCodeHash);
    console.log("GuardianLogicAddress:", GuardianLogicAddress);
    // if not deployed, deploy
    if (await ethers.provider.getCode(GuardianLogicAddress) === '0x') {
        console.log("GuardianLogic not deployed, deploying...");
        const increaseGasLimit = (estimatedGasLimit: BigNumber) => {
            return ethers.BigNumber.from(Math.pow(10, 7) + '');
            //return estimatedGasLimit.mul(10)  // 10x gas
        }
        const create2FactoryContract = Create2Factory__factory.connect(create2Factory, EOA);
        const estimatedGas = await create2FactoryContract.estimateGas.deploy(GuardianLogicBytecode, salt);
        const tx = await create2FactoryContract.deploy(GuardianLogicBytecode, salt, { gasLimit: increaseGasLimit(estimatedGas) })
        console.log("GuardianLogic tx:", tx.hash);
        while (await ethers.provider.getCode(GuardianLogicAddress) === '0x') {
            console.log("GuardianLogic not deployed, waiting...");
            await new Promise(r => setTimeout(r, 3000));
        }
        console.log("GuardianLogic deployed, verifying...");
        try {
            await run("verify:verify", {
                address: GuardianLogicAddress,
                constructorArguments: [],
            });
        } catch (error) {
            console.log("GuardianLogic verify failed:", error);
        }
    } else {
    }

    // #endregion GuardianLogic

    // #region deploy wallet

    const upgradeDelay = 10;
    const guardianDelay = 10;
    const walletAddress = await EIP4337Lib.calculateWalletAddress(
        WalletLogicAddress,
        EntryPointAddress,
        walletOwner,
        upgradeDelay,
        guardianDelay,
        EIP4337Lib.Defines.AddressZero,
        WETHContractAddress,
        WETHTokenPaymasterAddress,
        0,
        create2Factory
    );

    console.log('walletAddress: ' + walletAddress);

    // send 0.02 WETH to wallet
    const WETHContract = WETH9__factory.connect(WETHContractAddress, EOA);
    const _b = await WETHContract.balanceOf(walletAddress);
    if (_b.lt(ethers.utils.parseEther('0.02'))) {
        console.log('sending 0.05 WETH to wallet');
        await WETHContract.transferFrom(EOA.address, walletAddress, ethers.utils.parseEther('0.05'));
    }

    const activateOp = EIP4337Lib.activateWalletOp(
        WalletLogicAddress,
        EntryPointAddress,
        walletOwner,
        upgradeDelay,
        guardianDelay,
        EIP4337Lib.Defines.AddressZero,
        WETHContractAddress,
        WETHTokenPaymasterAddress,
        0,
        create2Factory,
        3000000000,// 30Gwei
        500000000// 5Gwei 
    );

    const userOpHash = activateOp.getUserOpHash(EntryPointAddress, chainId);

    activateOp.signWithSignature(
        walletOwner,
        Utils.signMessage(userOpHash, walletOwnerPrivateKey)
    );

    await EIP4337Lib.RPC.simulateValidation(ethers.provider, EntryPointAddress, activateOp);


    const EntryPoint = EntryPoint__factory.connect(EntryPointAddress, EOA);
    const re = await EntryPoint.handleOps([activateOp], EOA.address);
    console.table(re);

    // #endregion deploy wallet


}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});