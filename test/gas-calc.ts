import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { SoulWalletFactory__factory, SoulWalletProxy__factory, SoulWallet__factory } from "../src/types/index";
import { Utils } from "./Utils";
import { IApproveToken, SoulWalletLib, UserOperation } from 'soul-wallet-lib';


describe("SoulWalletContract", function () {

    async function infra() {

        // get accounts
        const accounts = await ethers.getSigners();

        // new account
        const walletOwner = await ethers.Wallet.createRandom();

        let chainId = await (await ethers.provider.getNetwork()).chainId;
        // #region SingletonFactory 

        let SingletonFactory: string = (await (await ethers.getContractFactory("SingletonFactory")).deploy()).address;

        // #endregion

        // #region SoulWalletLogic
        const SoulWalletLogic = {
            contract: await (await ethers.getContractFactory("SoulWallet")).deploy()
        };

        // #endregion

        // #region EntryPoint  
        const EntryPoint = {
            contract: await (await ethers.getContractFactory("EntryPoint")).deploy()
        };

        // #endregion

        // #region USDC
        const USDC = {
            contract: await (await ethers.getContractFactory("USDCoin")).deploy()
        };

        const DAI = {
            contract: await (await ethers.getContractFactory("USDCoin")).deploy()
        };

        // #endregion
        const MockOracle = {
            contract: await (await ethers.getContractFactory("MockOracle")).deploy()
        };

        // #region PriceOracle
        const PriceOracle = {
            contract: await (await ethers.getContractFactory("PriceOracle")).deploy(MockOracle.contract.address)
        };
        // #endregion


        // #region wallet factory
        const WalletFactory = {
            contract: await (await ethers.getContractFactory("SoulWalletFactory")).deploy(SoulWalletLogic.contract.address, SingletonFactory)
        };

        // #endregion

        // #region TokenPaymaster
        const TokenPaymaster = {
            contract: await (await ethers.getContractFactory("TokenPaymaster")).deploy(
                EntryPoint.contract.address,
                accounts[0].address,
                WalletFactory.contract.address
            )
        };
        await TokenPaymaster.contract.setToken(
            [USDC.contract.address, DAI.contract.address],
            [PriceOracle.contract.address, PriceOracle.contract.address]);

        const _paymasterStake = '' + Math.pow(10, 17);
        await TokenPaymaster.contract.addStake(
            1, {
            from: accounts[0].address,
            value: _paymasterStake
        });
        await TokenPaymaster.contract.deposit({
            from: accounts[0].address,
            value: _paymasterStake
        });

        // #endregion TokenPaymaster

        // #region guardian logic

        const GuardianLogic = {
            contract: await (await ethers.getContractFactory("GuardianMultiSigWallet")).deploy()
        }

        // #endregion


        const soulWalletLib = new SoulWalletLib(SingletonFactory);

        const bundler = new soulWalletLib.Bundler(EntryPoint.contract.address, ethers.provider);

        return {
            soulWalletLib,
            bundler,
            chainId,
            accounts,
            walletOwner,
            SingletonFactory,
            SoulWalletLogic,
            EntryPoint,
            USDC,
            DAI,
            TokenPaymaster,
            GuardianLogic,
            PriceOracle,
            WalletFactory
        };
    }

    function randomAddress() {
        return ethers.Wallet.createRandom().address;
    }

    const EIP1559Gas = {
        // 60Gwei
        maxFeePerGas: ethers.utils.parseUnits('20', 'gwei').toHexString(),
        // 5Gwei
        maxPriorityFeePerGas: ethers.utils.parseUnits('1', 'gwei').toHexString(),
    }

    async function _activateWallet_withETH() {
        //describe("activate wallet", async () => {
        const { soulWalletLib, bundler, WalletFactory, chainId, accounts, SingletonFactory, walletOwner, SoulWalletLogic, EntryPoint } = await infra();

        const upgradeDelay = 86400;
        const guardianDelay = 86400;

        // get proxy code
        const proxyCode = await WalletFactory.contract.proxyCode();

        const randomGuardian = randomAddress();
        const walletAddress = await WalletFactory.contract.getWalletAddress(
            EntryPoint.contract.address,
            walletOwner.address,
            guardianDelay,
            upgradeDelay,
            randomGuardian,
            SoulWalletLib.Defines.bytes32_zero
        );
        {
            const walletAddress_local = await soulWalletLib.calculateWalletAddress(
                SoulWalletLogic.contract.address,
                EntryPoint.contract.address,
                walletOwner.address,
                upgradeDelay,
                guardianDelay,
                randomGuardian,
                undefined,
                SingletonFactory, {
                contractInterface: SoulWalletProxy__factory.abi,
                bytecode: proxyCode
            }
            );
            expect(walletAddress).to.equal(walletAddress_local);
        }
        const activateOp = soulWalletLib.activateWalletOp(
            SoulWalletLogic.contract.address,
            EntryPoint.contract.address,
            walletOwner.address,
            upgradeDelay,
            guardianDelay,
            randomGuardian,
            '0x',
            EIP1559Gas.maxFeePerGas,
            EIP1559Gas.maxPriorityFeePerGas,
            undefined,
            WalletFactory.contract.address,
            SingletonFactory,
            {
                contractInterface: SoulWalletProxy__factory.abi,
                bytecode: proxyCode
            }
        );
        const userOpHash = activateOp.getUserOpHash(EntryPoint.contract.address, chainId);
        const requiredPrefund = activateOp.requiredPrefund();
        //console.log('requiredPrefund: ', ethers.utils.formatEther(requiredPrefund), 'ETH');
        // send eth to wallet
        await accounts[0].sendTransaction({
            to: walletAddress,
            value: requiredPrefund
        });


        activateOp.signWithSignature(
            walletOwner.address,
            Utils.signMessage(userOpHash, walletOwner.privateKey)
        );
        const validation = await bundler.simulateValidation(activateOp);
        if (validation.status !== 0) {
            throw new Error(`error code:${validation.status}`);
        }
        // calc gas cost
        const gasCost = await EntryPoint.contract.estimateGas.handleOps([activateOp], accounts[0].address);
        //console.log('gasCost: ', gasCost.toString(), 'gas');
        // get gas price
        const gasPrice = await ethers.provider.getGasPrice();
        // get balance of accounts[0].address
        const balance_before = await ethers.provider.getBalance(accounts[0].address);
        await EntryPoint.contract.handleOps([activateOp], accounts[1].address, {
            gasLimit: gasCost.mul(2),
            gasPrice: gasPrice
        });
        const balance_after = await ethers.provider.getBalance(accounts[0].address);
        const cost_eth = balance_before.sub(balance_after);
        const cost_gas = cost_eth.div(gasPrice);
        //console.log('gasCost: ', cost_gas.toString(), 'gas');

        const code = await ethers.provider.getCode(walletAddress);
        expect(code).to.not.equal('0x');


        // send eth
        const sendETHOP = await soulWalletLib.Tokens.ETH.transfer(
            ethers.provider,
            walletAddress,
            0,
            EntryPoint.contract.address,
            SoulWalletLib.Defines.AddressZero,
            EIP1559Gas.maxFeePerGas,
            EIP1559Gas.maxPriorityFeePerGas,
            accounts[3].address,
            '0xf'
        );
        if (!sendETHOP) {
            throw new Error("sendETHOP is null");
        }

        const sendETHOPHash = sendETHOP.getUserOpHash(EntryPoint.contract.address, chainId);

        sendETHOP.signWithSignature(
            walletOwner.address,
            Utils.signMessage(sendETHOPHash, walletOwner.privateKey)
        );

        const sendETHOPValidation = await bundler.simulateValidation(sendETHOP);
        if (sendETHOPValidation.status !== 0) {
            throw new Error(`error code:${sendETHOPValidation.status}`);
        }
        // get balance of accounts[0].address
        const sendETHOP_balance_before = await ethers.provider.getBalance(accounts[0].address);
        await EntryPoint.contract.handleOps([sendETHOP], accounts[1].address, {
            gasLimit: gasCost.mul(2),
            gasPrice: gasPrice
        });
        const sendETHOP_balance_after = await ethers.provider.getBalance(accounts[0].address);
        const sendETHOP_cost_eth = sendETHOP_balance_before.sub(sendETHOP_balance_after);
        const sendETHOP_cost_gas = sendETHOP_cost_eth.div(gasPrice);


        return {
            activateGas: cost_gas,
            requiredPrefund,
            transferGas: sendETHOP_cost_gas,
        };

    }
    async function activateWallet_withETH() {
        const runTimes = 10;
        let activateMinGas: BigNumber = BigNumber.from('0xfffffffffffffffffffffffffffffff');
        let activateMaxGas: BigNumber = BigNumber.from(0);
        let activateTotalGas: BigNumber = BigNumber.from(0);

        let transferMinGas: BigNumber = BigNumber.from('0xfffffffffffffffffffffffffffffff');
        let transferMaxGas: BigNumber = BigNumber.from(0);
        let transferTotalGas: BigNumber = BigNumber.from(0);

        for (let index = 0; index < runTimes; index++) {
            const cost = await _activateWallet_withETH();
            activateTotalGas = activateTotalGas.add(cost.activateGas);
            transferTotalGas = transferTotalGas.add(cost.transferGas);
            if (cost.activateGas.lt(activateMinGas)) {
                activateMinGas = cost.activateGas;
            }
            if (cost.activateGas.gt(activateMaxGas)) {
                activateMaxGas = cost.activateGas;
            }
            if (cost.transferGas.lt(transferMinGas)) {
                transferMinGas = cost.transferGas;
            }
            if (cost.transferGas.gt(transferMaxGas)) {
                transferMaxGas = cost.transferGas;
            }

        }
        console.log('activate wallet with ETH');
        console.log('activateMinGas: ', activateMinGas.toString(), 'gas');
        console.log('activateMaxGas: ', activateMaxGas.toString(), 'gas');
        console.log('activateAvgGas: ', activateTotalGas.div(runTimes).toString(), 'gas');
        console.log('transferMinGas: ', transferMinGas.toString(), 'gas');
        console.log('transferMaxGas: ', transferMaxGas.toString(), 'gas');
        console.log('transferAvgGas: ', transferTotalGas.div(runTimes).toString(), 'gas');
    }


    async function _activateWallet_WithUSDCPaymaster() {
        //describe("activate wallet", async () => {
        const { soulWalletLib, bundler, WalletFactory, chainId, accounts, SingletonFactory, walletOwner, SoulWalletLogic, EntryPoint, USDC, DAI, TokenPaymaster, GuardianLogic } = await infra();;

        const upgradeDelay = 86400;
        const guardianDelay = 86400;

        // get proxy code
        const proxyCode = await WalletFactory.contract.proxyCode();

        const randomGuardian = randomAddress();
        const walletAddress = await WalletFactory.contract.getWalletAddress(
            EntryPoint.contract.address,
            walletOwner.address,
            guardianDelay,
            upgradeDelay,
            randomGuardian,
            SoulWalletLib.Defines.bytes32_zero
        );
        {
            const walletAddress_local = await soulWalletLib.calculateWalletAddress(
                SoulWalletLogic.contract.address,
                EntryPoint.contract.address,
                walletOwner.address,
                upgradeDelay,
                guardianDelay,
                randomGuardian,
                undefined,
                SingletonFactory, {
                contractInterface: SoulWalletProxy__factory.abi,
                bytecode: proxyCode
            }
            );
            expect(walletAddress).to.equal(walletAddress_local);
        }
        const activateOp = soulWalletLib.activateWalletOp(
            SoulWalletLogic.contract.address,
            EntryPoint.contract.address,
            walletOwner.address,
            upgradeDelay,
            guardianDelay,
            randomGuardian,
            TokenPaymaster.contract.address,
            EIP1559Gas.maxFeePerGas,
            EIP1559Gas.maxPriorityFeePerGas,
            undefined,
            WalletFactory.contract.address,
            SingletonFactory,
            {
                contractInterface: SoulWalletProxy__factory.abi,
                bytecode: proxyCode
            }
        );
        const requiredPrefund = activateOp.requiredPrefund();
        // get USDC exchangeRate
        const exchangePrice = await soulWalletLib.getPaymasterExchangePrice(ethers.provider, TokenPaymaster.contract.address, USDC.contract.address, true);
        const tokenDecimals = exchangePrice.tokenDecimals || 6;
        // print price now
        // get required USDC : (requiredPrefund/10^18) * (exchangePrice.price/10^exchangePrice.decimals)
        const requiredUSDC = requiredPrefund.mul(exchangePrice.price)
            .mul(BigNumber.from(10).pow(tokenDecimals))
            .div(BigNumber.from(10).pow(exchangePrice.decimals))
            .div(BigNumber.from(10).pow(18));
        const maxUSDC = requiredUSDC.mul(110).div(100); // 10% more
        let paymasterAndData = soulWalletLib.getPaymasterData(TokenPaymaster.contract.address, USDC.contract.address, maxUSDC);
        activateOp.paymasterAndData = paymasterAndData;
        {
            // send maxUSDC USDC to wallet
            await USDC.contract.transfer(walletAddress, maxUSDC);
            // get balance of USDC
            const usdcBalance = await USDC.contract.balanceOf(walletAddress);
        }
        const approveData: IApproveToken[] = [
            {
                token: USDC.contract.address,
                spender: TokenPaymaster.contract.address,
                value: ethers.utils.parseEther('100').toString()
            }
            ,
            {
                token: DAI.contract.address,
                spender: TokenPaymaster.contract.address,
                //value: ethers.utils.parseEther('100').toString()
            }
        ];
        const approveCallData = await soulWalletLib.Tokens.ERC20.getApproveCallData(ethers.provider, walletAddress, approveData);
        activateOp.callData = approveCallData.callData;
        activateOp.callGasLimit = approveCallData.callGasLimit;


        const userOpHash = activateOp.getUserOpHash(EntryPoint.contract.address, chainId);

        activateOp.signWithSignature(
            walletOwner.address,
            Utils.signMessage(userOpHash, walletOwner.privateKey)
        );
        const validation = await bundler.simulateValidation(activateOp);
        if (validation.status !== 0) {
            throw new Error(`error code:${validation.status}`);
        }
        // calc gas cost
        const gasCost = await EntryPoint.contract.estimateGas.handleOps([activateOp], accounts[0].address);
        //console.log('gasCost: ', gasCost.toString(), 'gas');
        const gasPrice = await ethers.provider.getGasPrice();
        // get balance of accounts[0].address
        const balance_before = await ethers.provider.getBalance(accounts[0].address);
        await EntryPoint.contract.handleOps([activateOp], accounts[1].address, {
            gasLimit: gasCost.mul(2),
            gasPrice: gasPrice
        });
        const balance_after = await ethers.provider.getBalance(accounts[0].address);
        const cost_eth = balance_before.sub(balance_after);
        const cost_gas = cost_eth.div(gasPrice);
        //console.log('gasCost: ', cost_gas.toString(), 'gas');

        const code = await ethers.provider.getCode(walletAddress);
        expect(code).to.not.equal('0x');

        //#region

        return {
            gasCost,
            requiredPrefund
        };
    }

    async function activateWallet_WithUSDCPaymaster() {
        const runTimes = 10;
        let minGas: BigNumber = BigNumber.from('0xfffffffffffffffffffffffffffffff');
        let maxGas: BigNumber = BigNumber.from(0);
        let totalGas: BigNumber = BigNumber.from(0);
        for (let index = 0; index < runTimes; index++) {
            const gas = await (await _activateWallet_WithUSDCPaymaster()).gasCost;
            totalGas = totalGas.add(gas);
            if (gas.lt(minGas)) {
                minGas = gas;
            }
            if (gas.gt(maxGas)) {
                maxGas = gas;
            }
        }
        console.log('activateMinGas: ', minGas.toString(), 'gas');
        console.log('activateMaxGas: ', maxGas.toString(), 'gas');
        console.log('activateAvgGas: ', totalGas.div(runTimes).toString(), 'gas');
        console.log('requiredPrefund: ', ethers.utils.formatEther(await (await _activateWallet_WithUSDCPaymaster()).requiredPrefund), 'ETH');
    }







    describe("wallet test", async function () {
        it("activate wallet(ETH)", activateWallet_withETH);
        it("activate wallet(USDC)", activateWallet_WithUSDCPaymaster);
    });



});