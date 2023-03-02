/*
 * @Description: 
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-12-24 14:24:47
 * @LastEditors: cejay
 * @LastEditTime: 2023-03-02 18:28:43
 */
import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { IApproveToken, ITransaction, SoulWalletLib, UserOperation } from 'soul-wallet-lib';
import { SoulWallet__factory } from "../src/types/index";
import { Utils } from "./Utils";
import * as ethUtil from 'ethereumjs-util';
import { Bundler } from "soul-wallet-lib/dist/utils/bundler";


const log_on = false;
const log = (message?: any, ...optionalParams: any[]) => { if (log_on) console.log(message, ...optionalParams) };

describe("SoulWalletContract", function () {

    // We define a fixture to reuse the same setup in every test.
    // We use loadFixture to run this setup once, snapshot that state,
    // and reset Hardhat Network to that snapshot in every test.
    async function deployFixture() {
        // get accounts
        const accounts = await ethers.getSigners();

        // new account
        const walletOwner = await ethers.Wallet.createRandom();

        let chainId = await (await ethers.provider.getNetwork()).chainId;
        log("chainId:", chainId);

        // #region SingletonFactory 

        let SingletonFactory: string = SoulWalletLib.Defines.SingletonFactoryAddress;
        let code = await ethers.provider.getCode(SingletonFactory);
        if (code === '0x') {
            SingletonFactory = (await (await ethers.getContractFactory("SingletonFactory")).deploy()).address;
            code = await ethers.provider.getCode(SingletonFactory);
            expect(code).to.not.equal('0x');
        }
        const soulWalletLib = new SoulWalletLib(SingletonFactory);

        // #endregion

        // #region SoulWalletLogic
        const SoulWalletLogic = {
            contract: await (await ethers.getContractFactory("SoulWallet")).deploy()
        };
        log("SoulWalletLogic:", SoulWalletLogic.contract.address);
        // get SoulWalletLogic contract code
        const SoulWalletLogicCode = await ethers.provider.getCode(SoulWalletLogic.contract.address);

        // calculate SoulWalletLogic contract code hash
        const SoulWalletLogicCodeHash = ethers.utils.keccak256(SoulWalletLogicCode);
        log("SoulWalletLogicCodeHash:", SoulWalletLogicCodeHash);
        // #endregion

        // #region EntryPoint  
        const EntryPoint = {
            contract: await (await ethers.getContractFactory("EntryPoint")).deploy()
        };
        log("EntryPoint:", EntryPoint.contract.address);
        // #endregion

        // #region USDC
        const USDC = {
            contract: await (await ethers.getContractFactory("USDCoin")).deploy()
        };
        log("USDC:", USDC.contract.address);

        const DAI = {
            contract: await (await ethers.getContractFactory("USDCoin")).deploy()
        };
        log("DAI:", DAI.contract.address);

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
        const _walletFactoryAddress = await soulWalletLib.Utils.deployFactory.deploy(SoulWalletLogic.contract.address, ethers.provider, accounts[0]);

        const WalletFactory = {
            contract: await ethers.getContractAt("SoulWalletFactory", _walletFactoryAddress)
        };
        log("SoulWalletFactory:", WalletFactory.contract.address);


        // #endregion


        const bundler = new soulWalletLib.Bundler(EntryPoint.contract.address, ethers.provider);


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
        log("TokenPaymaster:", TokenPaymaster.contract.address);

        // #endregion TokenPaymaster

        // #region guardian logic

        const GuardianLogic = {
            contract: await (await ethers.getContractFactory("GuardianMultiSigWallet")).deploy()
        }
        log("GuardianLogic:", GuardianLogic.contract.address);

        // #endregion

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

    async function activateWallet_withETH() {
        //describe("activate wallet", async () => {
        const { soulWalletLib, bundler, chainId, accounts, SingletonFactory, walletOwner, SoulWalletLogic, EntryPoint, USDC, TokenPaymaster, GuardianLogic } = await loadFixture(deployFixture);

        const upgradeDelay = 30;
        const guardianDelay = 30;

        const guardians = [];
        const guardiansAddress = [];

        for (let i = 0; i < 10; i++) {
            const _account = await ethers.Wallet.createRandom();
            guardians.push({
                address: _account.address,
                privateKey: _account.privateKey
            });
            guardiansAddress.push(_account.address);
        }

        const guardianSalt = 'saltText<text or bytes32>';
        const gurdianAddressAndInitCode = soulWalletLib.Guardian.calculateGuardianAndInitCode(GuardianLogic.contract.address, guardiansAddress, Math.round(guardiansAddress.length / 2), guardianSalt);
        log('guardian address ==> ' + gurdianAddressAndInitCode.address);
        {
            // test guardian order (For user experience, guardian cannot rely on the order of address)
            const _guardiansAddress = [...guardiansAddress];
            const _guardianTmpItem = _guardiansAddress[0];
            _guardiansAddress[0] = _guardiansAddress[1];
            _guardiansAddress[1] = _guardianTmpItem;

            const _gurdianAddressAndInitCode = soulWalletLib.Guardian.calculateGuardianAndInitCode(GuardianLogic.contract.address, _guardiansAddress, Math.round(guardiansAddress.length / 2), guardianSalt);
            expect(_gurdianAddressAndInitCode.address).to.equal(gurdianAddressAndInitCode.address);
        }

        const walletAddress = await soulWalletLib.calculateWalletAddress(
            SoulWalletLogic.contract.address,
            EntryPoint.contract.address,
            walletOwner.address,
            upgradeDelay,
            guardianDelay,
            gurdianAddressAndInitCode.address
        );

        log('walletAddress: ' + walletAddress);

        //#region


        const activateOp = soulWalletLib.activateWalletOp(
            SoulWalletLogic.contract.address,
            EntryPoint.contract.address,
            walletOwner.address,
            upgradeDelay,
            guardianDelay,
            gurdianAddressAndInitCode.address,
            '0x',
            10000000000,// 100Gwei
            1000000000,// 10Gwei 
        );

        const userOpHash = activateOp.getUserOpHash(EntryPoint.contract.address, chainId);
        {
            // test toJson and fromJson
            const _activateOp = UserOperation.fromJSON(activateOp.toJSON());
            const _userOpHash = _activateOp.getUserOpHash(EntryPoint.contract.address, chainId);
            expect(_userOpHash).to.equal(userOpHash);
        }
        {
            const _userOpHashRaw = activateOp.getRawUserOpHash(EntryPoint.contract.address, chainId);
            const _userOpHashOnline = await EntryPoint.contract.getUserOpHash(activateOp);
            expect(_userOpHashOnline).to.equal(_userOpHashRaw);
        }

        {
            const requiredPrefund = activateOp.requiredPrefund();
            log('requiredPrefund: ', ethers.utils.formatEther(requiredPrefund), 'ETH');

            // send eth to wallet
            await accounts[0].sendTransaction({
                to: walletAddress,
                value: requiredPrefund
            });
            // get balance of walletaddress
            const balance = await ethers.provider.getBalance(walletAddress);
            log('balance: ' + balance, 'wei');
        }

        activateOp.signWithSignature(
            walletOwner.address,
            Utils.signMessage(userOpHash, walletOwner.privateKey)
        );

        //const activateOp = UserOperation.fromJSON(activateOp.toJSON());
        const validation = await bundler.simulateValidation(activateOp);
        if (validation.status !== 0) {
            throw new Error(`error code:${validation.status}`);
        }
        const simulate = await bundler.simulateHandleOp(activateOp);
        if (simulate.status !== 0) {
            throw new Error(`error code:${simulate.status}`);
        }

        log(`simulateHandleOp result:`, simulate);
        await EntryPoint.contract.handleOps([activateOp.getStruct()], accounts[0].address);
        const code = await ethers.provider.getCode(walletAddress);
        expect(code).to.not.equal('0x');
        let guardianInfo = await soulWalletLib.Guardian.getGuardian(ethers.provider, walletAddress);

        expect(guardianInfo?.currentGuardian).to.equal(gurdianAddressAndInitCode.address);

        return {
            chainId, accounts, GuardianLogic, SingletonFactory, EntryPoint, TokenPaymaster,
            soulWalletLib,
            bundler,
            walletAddress,
            walletOwner,
            guardian: gurdianAddressAndInitCode.address,
            guardianInitcode: gurdianAddressAndInitCode.initCode,
            guardians,
            guardianSalt,
            guardianDelay,
            USDC
        };
    }

    async function activateWallet_WithUSDCPaymaster() {
        //describe("activate wallet", async () => {
        const { soulWalletLib, bundler, chainId, accounts, SingletonFactory, walletOwner, SoulWalletLogic, EntryPoint, USDC, DAI, TokenPaymaster, GuardianLogic, WalletFactory } = await loadFixture(deployFixture);

        const upgradeDelay = 10;
        const guardianDelay = 10;

        const guardians = [];
        const guardiansAddress = [];

        for (let i = 0; i < 10; i++) {
            const _account = await ethers.Wallet.createRandom();
            guardians.push({
                address: _account.address,
                privateKey: _account.privateKey
            });
            guardiansAddress.push(_account.address);
        }

        const guardianSalt = 'saltText<text or bytes32>(USDC)';
        const gurdianAddressAndInitCode = soulWalletLib.Guardian.calculateGuardianAndInitCode(GuardianLogic.contract.address, guardiansAddress, Math.round(guardiansAddress.length / 2), guardianSalt);
        log('guardian address ==> ' + gurdianAddressAndInitCode.address);
        {
            // test guardian order (For user experience, guardian cannot rely on the order of address)
            const _guardiansAddress = [...guardiansAddress];
            const _guardianTmpItem = _guardiansAddress[0];
            _guardiansAddress[0] = _guardiansAddress[1];
            _guardiansAddress[1] = _guardianTmpItem;

            const _gurdianAddressAndInitCode = soulWalletLib.Guardian.calculateGuardianAndInitCode(GuardianLogic.contract.address, _guardiansAddress, Math.round(guardiansAddress.length / 2), guardianSalt);
            expect(_gurdianAddressAndInitCode.address).to.equal(gurdianAddressAndInitCode.address);
        }

        const walletAddress = await soulWalletLib.calculateWalletAddress(
            SoulWalletLogic.contract.address,
            EntryPoint.contract.address,
            walletOwner.address,
            upgradeDelay,
            guardianDelay,
            gurdianAddressAndInitCode.address
        );

        log('walletAddress: ' + walletAddress);

        //#region


        // #endregion

        const activateOp = soulWalletLib.activateWalletOp(
            SoulWalletLogic.contract.address,
            EntryPoint.contract.address,
            walletOwner.address,
            upgradeDelay,
            guardianDelay,
            gurdianAddressAndInitCode.address,
            TokenPaymaster.contract.address,
            10000000000,// 100Gwei
            1000000000// 10Gwei 
        );
        // calculate eth cost
        const requiredPrefund = activateOp.requiredPrefund();
        log('requiredPrefund: ', ethers.utils.formatEther(requiredPrefund), 'ETH');
        // get USDC exchangeRate
        const exchangePrice = await soulWalletLib.getPaymasterExchangePrice(ethers.provider, TokenPaymaster.contract.address, USDC.contract.address, true);
        const tokenDecimals = exchangePrice.tokenDecimals || 6;
        // print price now
        log('exchangePrice: ' + ethers.utils.formatUnits(exchangePrice.price, exchangePrice.decimals), 'USDC/ETH');
        // get required USDC : (requiredPrefund/10^18) * (exchangePrice.price/10^exchangePrice.decimals)
        const requiredUSDC = requiredPrefund.mul(exchangePrice.price)
            .mul(BigNumber.from(10).pow(tokenDecimals))
            .div(BigNumber.from(10).pow(exchangePrice.decimals))
            .div(BigNumber.from(10).pow(18));
        log('requiredUSDC: ' + ethers.utils.formatUnits(requiredUSDC, tokenDecimals), 'USDC');
        const maxUSDC = requiredUSDC.mul(110).div(100); // 10% more
        let paymasterAndData = soulWalletLib.getPaymasterData(TokenPaymaster.contract.address, USDC.contract.address, maxUSDC);
        activateOp.paymasterAndData = paymasterAndData;
        {
            // send maxUSDC USDC to wallet
            await USDC.contract.transfer(walletAddress, maxUSDC);
            // get balance of USDC
            const usdcBalance = await USDC.contract.balanceOf(walletAddress);
            log('usdcBalance: ' + ethers.utils.formatUnits(usdcBalance, exchangePrice.tokenDecimals), 'USDC');
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
        const decoder = soulWalletLib.Utils.DecodeCallData.new();
        const decoded = await decoder.decode(approveCallData.callData);
        activateOp.callGasLimit = approveCallData.callGasLimit;
        log("init code", activateOp.initCode);

        const userOpHash = activateOp.getUserOpHash(EntryPoint.contract.address, chainId);

        activateOp.signWithSignature(
            walletOwner.address,
            Utils.signMessage(userOpHash, walletOwner.privateKey)
        );

        const validation = await bundler.simulateValidation(activateOp);
        if (validation.status !== 0) {
            throw new Error(`error code:${validation.status}`);
        }
        const simulate = await bundler.simulateHandleOp(activateOp);
        if (simulate.status !== 0) {
            throw new Error(`error code:${simulate.status}`);
        }

        await EntryPoint.contract.handleOps([activateOp.getStruct()], accounts[0].address);
        const code = await ethers.provider.getCode(walletAddress);
        expect(code).to.not.equal('0x');
        let guardianInfo = await soulWalletLib.Guardian.getGuardian(ethers.provider, walletAddress);

        expect(guardianInfo?.currentGuardian).to.equal(gurdianAddressAndInitCode.address);

        return {
            soulWalletLib,
            bundler,
            chainId, accounts, GuardianLogic, SingletonFactory, EntryPoint, TokenPaymaster,
            walletAddress,
            walletOwner,
            guardian: gurdianAddressAndInitCode.address,
            guardianInitcode: gurdianAddressAndInitCode.initCode,
            guardians,
            guardianSalt,
            guardianDelay,
            USDC
        };
    }

    async function transferToken() {
        const { soulWalletLib, walletAddress, walletOwner, bundler, guardian, guardianDelay, chainId, accounts, GuardianLogic, SingletonFactory, EntryPoint, TokenPaymaster, USDC } = await activateWallet_withETH();

        let nonce = await soulWalletLib.Utils.getNonce(walletAddress, ethers.provider);

        await accounts[0].sendTransaction({
            to: walletAddress,
            value: ethers.utils.parseEther('0.001').toHexString()
        });

        const sendETHOP = await soulWalletLib.Tokens.ETH.transfer(
            ethers.provider,
            walletAddress,
            nonce,
            EntryPoint.contract.address,
            '0x',
            10000000000,// 100Gwei
            1000000000,// 10Gwei
            accounts[1].address,
            ethers.utils.parseEther('0.0001').toHexString()
        );
        if (!sendETHOP) {
            throw new Error('setGuardianOP is null');
        }
        const sendETHOPuserOpHash = sendETHOP.getUserOpHash(EntryPoint.contract.address, chainId);
        const sendETHOPSignature = Utils.signMessage(sendETHOPuserOpHash, walletOwner.privateKey)
        sendETHOP.signWithSignature(walletOwner.address, sendETHOPSignature);

        let validation = await bundler.simulateValidation(sendETHOP);
        if (validation.status !== 0) {
            throw new Error(`error code:${validation.status}`);
        }
        let simulate = await bundler.simulateHandleOp(sendETHOP);
        if (simulate.status !== 0) {
            throw new Error(`error code:${simulate.status}`);
        }

        // get balance of accounts[1].address
        const balanceBefore = await ethers.provider.getBalance(accounts[1].address);
        await EntryPoint.contract.handleOps([sendETHOP.getStruct()], accounts[0].address);
        // get balance of accounts[1].address
        const balanceAfter = await ethers.provider.getBalance(accounts[1].address);
        expect(balanceAfter.sub(balanceBefore).toString()).to.equal(ethers.utils.parseEther('0.0001').toString());

        nonce = await soulWalletLib.Utils.getNonce(walletAddress, ethers.provider);
        const rawtx: ITransaction[] = [{
            from: walletAddress,
            to: accounts[1].address,
            value: ethers.utils.parseEther('0.0001').toHexString(),
            data: '0x'
        }, {
            from: walletAddress,
            to: accounts[2].address,
            value: ethers.utils.parseEther('0.0002').toHexString(),
            data: '0x'
        }, {
            from: walletAddress,
            to: accounts[2].address,
            value: ethers.utils.parseEther('0.0001').toHexString(),
            data: '0x'
        }];
        const ConvertedOP = await soulWalletLib.Utils.fromTransaction(
            ethers.provider,
            EntryPoint.contract.address,
            rawtx,
            nonce,
            10000000000,// 100Gwei
            1000000000// 10Gwei
        );
        if (!ConvertedOP) {
            throw new Error('setGuardianOP is null');
        }
        const ConvertedOPuserOpHash = ConvertedOP.getUserOpHash(EntryPoint.contract.address, chainId);
        const ConvertedOPSignature = Utils.signMessage(ConvertedOPuserOpHash, walletOwner.privateKey)
        ConvertedOP.signWithSignature(walletOwner.address, ConvertedOPSignature);
        validation = await bundler.simulateValidation(ConvertedOP);
        if (validation.status !== 0) {
            throw new Error(`error code:${validation.status}`);
        }
        simulate = await bundler.simulateHandleOp(ConvertedOP);
        if (simulate.status !== 0) {
            throw new Error(`error code:${simulate.status}`);
        }
        // get balance of accounts[1].address
        const balanceBefore2 = await ethers.provider.getBalance(accounts[1].address);
        const balanceBefore3 = await ethers.provider.getBalance(accounts[2].address);
        await EntryPoint.contract.handleOps([ConvertedOP.getStruct()], accounts[0].address);
        // get balance of accounts[1].address
        const balanceAfter2 = await ethers.provider.getBalance(accounts[1].address);
        const balanceAfter3 = await ethers.provider.getBalance(accounts[2].address);
        expect(balanceAfter2.sub(balanceBefore2).toString()).to.equal(ethers.utils.parseEther('0.0001').toString());
        expect(balanceAfter3.sub(balanceBefore3).toString()).to.equal(ethers.utils.parseEther('0.0003').toString());


    }

    async function updateGuardian() {
        const { soulWalletLib, bundler, walletAddress, walletOwner, guardian, guardianDelay, chainId, accounts, GuardianLogic, EntryPoint } = await activateWallet_withETH();
        let guardianInfo = await soulWalletLib.Guardian.getGuardian(ethers.provider, walletAddress);

        expect(guardianInfo?.currentGuardian).to.equal(guardian);
        const guardians = [];
        const guardiansAddress = [];
        for (let i = 0; i < 10; i++) {
            const _guardian = await ethers.Wallet.createRandom();
            guardians.push({
                address: _guardian.address,
                privateKey: _guardian.privateKey
            });
            guardiansAddress.push(_guardian.address);
        }
        const guardianSalt = 'saltText' + Math.random();
        const gurdianAddressAndInitCode = soulWalletLib.Guardian.calculateGuardianAndInitCode(GuardianLogic.contract.address, guardiansAddress, Math.round(guardians.length / 2), guardianSalt);
        log('new guardian address ==> ' + gurdianAddressAndInitCode.address);
        const nonce = await soulWalletLib.Utils.getNonce(walletAddress, ethers.provider);

        const setGuardianOP = await soulWalletLib.Guardian.setGuardian(
            ethers.provider,
            walletAddress,
            gurdianAddressAndInitCode.address,
            nonce,
            EntryPoint.contract.address,
            '0x',
            10000000000,// 100Gwei
            1000000000,// 10Gwei
        );
        if (!setGuardianOP) {
            throw new Error('setGuardianOP is null');
        }
        const setGuardianOPuserOpHash = setGuardianOP.getUserOpHash(EntryPoint.contract.address, chainId);
        const setGuardianOPSignature = Utils.signMessage(setGuardianOPuserOpHash, walletOwner.privateKey)
        setGuardianOP.signWithSignature(walletOwner.address, setGuardianOPSignature);
        await EntryPoint.contract.handleOps([setGuardianOP.getStruct()], accounts[0].address);
        guardianInfo = await soulWalletLib.Guardian.getGuardian(ethers.provider, walletAddress);
        expect(guardianInfo?.currentGuardian).to.equal(guardian);
        // wait block for guardianDelay 
        await time.increaseTo((await time.latest()) + guardianDelay);
        guardianInfo = await soulWalletLib.Guardian.getGuardian(ethers.provider, walletAddress, await time.latest());
        expect(guardianInfo?.currentGuardian).to.equal(gurdianAddressAndInitCode.address);

        // test recoveryWallet
        await _recoveryWallet(soulWalletLib, bundler, guardians, gurdianAddressAndInitCode.initCode, walletAddress, walletOwner, gurdianAddressAndInitCode.address, chainId, accounts, GuardianLogic, EntryPoint);



    }

    async function recoveryWallet() {
        const { soulWalletLib, bundler, guardians, guardianInitcode, walletAddress, walletOwner, guardian, chainId, accounts, GuardianLogic, EntryPoint } = await activateWallet_withETH();
        await _recoveryWallet(soulWalletLib, bundler, guardians, guardianInitcode, walletAddress, walletOwner, guardian, chainId, accounts, GuardianLogic, EntryPoint);
    }
    async function _recoveryWallet(soulWalletLib: SoulWalletLib, bundler: Bundler, guardians: any[], guardianInitcode: any, walletAddress: string, walletOwner: any, guardian: string, chainId: number, accounts: any[], GuardianLogic: any, EntryPoint: any) {

        let guardianInfo = await soulWalletLib.Guardian.getGuardian(ethers.provider, walletAddress, await time.latest());
        expect(guardianInfo?.currentGuardian).to.equal(guardian);

        const nonce = await soulWalletLib.Utils.getNonce(walletAddress, ethers.provider);
        const newWalletOwner = await ethers.Wallet.createRandom();
        const transferOwnerOP = await soulWalletLib.Guardian.transferOwner(
            ethers.provider,
            walletAddress,
            nonce,
            EntryPoint.contract.address,
            '0x',
            10000000000,// 100Gwei
            1000000000,// 10Gwei, 
            newWalletOwner.address
        );
        if (!transferOwnerOP) {
            throw new Error('transferOwnerOP is null');
        }
        transferOwnerOP.callGasLimit = BigNumber.from(transferOwnerOP.callGasLimit).mul(2).toHexString();
        transferOwnerOP.preVerificationGas = BigNumber.from(transferOwnerOP.preVerificationGas).mul(2).toHexString();

        // get requeired eth
        const requiredEth = await transferOwnerOP.requiredPrefund();
        // send eth to wallet
        await accounts[0].sendTransaction({
            to: walletAddress,
            value: requiredEth
        });

        const transferOwnerOPuserOpHash = transferOwnerOP.getUserOpHash(EntryPoint.contract.address, chainId);

        const guardianSignArr: any[] = [];
        for (let index = 0; index < Math.round(guardians.length / 2); index++) {
            const _guardian = guardians[index];
            const _address = _guardian.address;
            const _privateKey = _guardian.privateKey;
            const _signature = Utils.signMessage(transferOwnerOPuserOpHash, _privateKey);
            const _recoverAddress = Utils.recoverAddress(transferOwnerOPuserOpHash, _signature);
            expect(_recoverAddress.toLowerCase()).to.equal(_address.toLowerCase());
            guardianSignArr.push(
                {
                    contract: false,
                    address: _address,
                    signature: _signature
                }
            );
        }
        const signature = soulWalletLib.Guardian.packGuardiansSignByInitCode(guardian, guardianSignArr, guardianInitcode);
        transferOwnerOP.signature = signature;
        const validation = await bundler.simulateValidation(transferOwnerOP);
        if (validation.status !== 0) {
            throw new Error(`error code:${validation.status}`);
        }
        const simulate = await bundler.simulateHandleOp(transferOwnerOP);
        if (simulate.status !== 0) {
            throw new Error(`error code:${simulate.status}`);
        }


        const walletContract = new ethers.Contract(walletAddress, SoulWallet__factory.abi, ethers.provider);
        expect(await walletContract.isOwner(walletOwner.address)).to.equal(true);
        await EntryPoint.contract.handleOps([transferOwnerOP.getStruct()], accounts[0].address);
        expect(await walletContract.isOwner(walletOwner.address)).to.equal(false);
        expect(await walletContract.isOwner(newWalletOwner.address)).to.equal(true);

    }

    async function interfaceResolver() {
        const { walletAddress } = await activateWallet_WithUSDCPaymaster();
        const walletContract = new ethers.Contract(
            walletAddress,
            SoulWallet__factory.abi,
            ethers.provider
        );

        const SUPPORT_INTERFACE_ID = "0x01ffc9a7";
        const ERC721_INTERFACE_ID = "0x150b7a02";
        const ERC1155_INTERFACE_ID = "0x4e2312e0";
        const AccessControl_Enumerable_INTERFACE_ID = "0x5a05180f";
        const NO_SUPPORT_ID = "0xffffffff";
        const RANDOM_NO_SUPPORT_ID = "0x1fffffff";

        let support = await walletContract.supportsInterface(
            SUPPORT_INTERFACE_ID
        );
        expect(support).to.equal(true);
        support = await walletContract.supportsInterface(ERC721_INTERFACE_ID);
        expect(support).to.equal(true);
        support = await walletContract.supportsInterface(ERC1155_INTERFACE_ID);
        expect(support).to.equal(true);
        support = await walletContract.supportsInterface(AccessControl_Enumerable_INTERFACE_ID);
        expect(support).to.equal(true);
        support = await walletContract.supportsInterface(NO_SUPPORT_ID);
        expect(support).to.equal(false);
        support = await walletContract.supportsInterface(RANDOM_NO_SUPPORT_ID);
        expect(support).to.equal(false);
        await expect(
            await walletContract.callStatic.onERC1155Received(
                SoulWalletLib.Defines.AddressZero,
                SoulWalletLib.Defines.AddressZero,
                0,
                0,
                "0x"
            )
        ).to.be.eq("0xf23a6e61");
        await expect(
            await walletContract.callStatic.onERC1155BatchReceived(
                SoulWalletLib.Defines.AddressZero,
                SoulWalletLib.Defines.AddressZero,
                [0],
                [0],
                "0x"
            )
        ).to.be.eq("0xbc197c81");
    }

    async function coverageTest() {
        const { walletAddress, walletOwner, guardian, guardianDelay, chainId, accounts, GuardianLogic, SingletonFactory, EntryPoint, USDC } = await activateWallet_WithUSDCPaymaster();
        const walletContract = new ethers.Contract(walletAddress, SoulWallet__factory.abi, ethers.provider);

        // getVersion
        const version = await walletContract.getVersion();
        expect(version).to.equal(1);

        const isOwner = await walletContract.isOwner(walletOwner.address);

        // test isValidSignature() function

        const msg = "0x40e146fb1960313f694b3fcfd04b8b469e19936864b618e0f4b6cb504fbf4fae";
        const messageHex = Buffer.from(ethers.utils.arrayify(msg));
        const _privateKey = Buffer.from(walletOwner.privateKey.substring(2), "hex");
        // import * as ethUtil from 'ethereumjs-util';
        const _signature = ethUtil.ecsign(messageHex, _privateKey);
        const signature = ethUtil.toRpcSig(_signature.v, _signature.r, _signature.s);
        const selector = await walletContract.isValidSignature(
            msg,
            signature
        );
        expect(selector).to.equal('0x1626ba7e');



    }

    describe("wallet test", async function () {
        it("activate wallet(ETH)", activateWallet_withETH);
        it("activate wallet(USDC)", activateWallet_WithUSDCPaymaster);
        it("transferToken", transferToken);
        it("update guardian", updateGuardian);
        // it("recovery wallet", recoveryWallet);
        // it("interface resolver", interfaceResolver);
        // it("other coverage test", coverageTest);
    });



});