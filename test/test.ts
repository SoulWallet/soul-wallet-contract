/*
 * @Description: 
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-12-24 14:24:47
 * @LastEditors: cejay
 * @LastEditTime: 2023-02-14 18:18:18
 */
import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { IApproveToken, SoulWalletLib, UserOperation } from 'soul-wallet-lib';
import { SmartWallet__factory } from "../src/types/index";
import { Utils } from "./Utils";

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
            contract: await (await ethers.getContractFactory("SmartWallet")).deploy()
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
            contract: await ethers.getContractAt("SmartWalletFactory", _walletFactoryAddress)
        };
        log("SmartWalletFactory:", WalletFactory.contract.address);


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
        await TokenPaymaster.contract.setToken([USDC.contract.address], [PriceOracle.contract.address]);

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

        const guardianSalt = 'saltText<text or bytes32>';
        const gurdianAddressAndInitCode = soulWalletLib.Guardian.calculateGuardianAndInitCode(GuardianLogic.contract.address, guardiansAddress, Math.round(guardiansAddress.length / 2), guardianSalt);
        log('guardian address ==> ' + gurdianAddressAndInitCode.address);
        {
            // test guardian order (For user experience, guardian cannot rely on the order of address)
            const _guardiansAddress = [...guardiansAddress];
            const _guardianTmpItem = _guardiansAddress[0];
            _guardiansAddress[0] = _guardiansAddress[1];
            _guardiansAddress[1] = _guardianTmpItem;

            const gurdianAddressAndInitCode = soulWalletLib.Guardian.calculateGuardianAndInitCode(GuardianLogic.contract.address, _guardiansAddress, Math.round(guardiansAddress.length / 2), guardianSalt);
            expect(gurdianAddressAndInitCode.address).to.equal(gurdianAddressAndInitCode.address);

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
            const _userOpHash = await EntryPoint.contract.getUserOpHash(activateOp);
            expect(_userOpHash).to.equal(userOpHash);
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
        await EntryPoint.contract.handleOps([activateOp], accounts[0].address);
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

            const gurdianAddressAndInitCode = soulWalletLib.Guardian.calculateGuardianAndInitCode(GuardianLogic.contract.address, _guardiansAddress, Math.round(guardiansAddress.length / 2), guardianSalt);
            expect(gurdianAddressAndInitCode.address).to.equal(gurdianAddressAndInitCode.address);

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

        await EntryPoint.contract.handleOps([activateOp], accounts[0].address);
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

    async function updateGuardian() {
        const { soulWalletLib, walletAddress, walletOwner, guardian, guardianDelay, chainId, accounts, GuardianLogic, SingletonFactory, EntryPoint, TokenPaymaster, USDC } = await activateWallet_withETH();
        let guardianInfo = await soulWalletLib.Guardian.getGuardian(ethers.provider, walletAddress);

        expect(guardianInfo?.currentGuardian).to.equal(guardian);
        const guardians: string[] = [];
        for (let i = 0; i < accounts.length; i++) {
            guardians.push(accounts[i].address);
        }
        const guardianSalt = 'saltText' + Math.random();
        const gurdianAddressAndInitCode = soulWalletLib.Guardian.calculateGuardianAndInitCode(GuardianLogic.contract.address, guardians, Math.round(guardians.length / 2), guardianSalt);
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
        await EntryPoint.contract.handleOps([setGuardianOP], accounts[0].address);
        guardianInfo = await soulWalletLib.Guardian.getGuardian(ethers.provider, walletAddress);
        expect(guardianInfo?.currentGuardian).to.equal(guardian);
        // wait block for guardianDelay 
        await time.increaseTo((await time.latest()) + guardianDelay);
        guardianInfo = await soulWalletLib.Guardian.getGuardian(ethers.provider, walletAddress, await time.latest());
        expect(guardianInfo?.currentGuardian).to.equal(gurdianAddressAndInitCode.address);

    }

    async function recoveryWallet() {
        const { soulWalletLib, bundler, USDC, guardians, guardianSalt, guardianInitcode, walletAddress, walletOwner, guardian, guardianDelay, chainId, accounts, GuardianLogic, SingletonFactory, EntryPoint, TokenPaymaster } = await activateWallet_withETH();
        let guardianInfo = await soulWalletLib.Guardian.getGuardian(ethers.provider, walletAddress);
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

        const transferOwnerOPuserOpHash = transferOwnerOP.getUserOpHash(EntryPoint.contract.address, chainId);

        const guardianSignArr: any[] = [];
        for (let index = 0; index < Math.round(guardians.length / 2); index++) {
            const _guardian = guardians[index];
            const _address = _guardian.address;
            const _privateKey = _guardian.privateKey;
            guardianSignArr.push(
                {
                    contract: false,
                    address: _address,
                    signature: Utils.signMessage(transferOwnerOPuserOpHash, _privateKey)
                }
            );
        }
        const signature = soulWalletLib.Guardian.packGuardiansSignByInitCode(guardian, guardianSignArr, 0, guardianInitcode);
        transferOwnerOP.signature = signature;

        const validation = await bundler.simulateValidation(transferOwnerOP);
        if (validation.status !== 0) {
            throw new Error(`error code:${validation.status}`);
        }
        const simulate = await bundler.simulateHandleOp(transferOwnerOP);
        if (simulate.status !== 0) {
            throw new Error(`error code:${simulate.status}`);
        }


        const walletContract = new ethers.Contract(walletAddress, SmartWallet__factory.abi, ethers.provider);
        expect(await walletContract.isOwner(walletOwner.address)).to.equal(true);
        await EntryPoint.contract.handleOps([transferOwnerOP], accounts[0].address);
        expect(await walletContract.isOwner(walletOwner.address)).to.equal(false);
        expect(await walletContract.isOwner(newWalletOwner.address)).to.equal(true);

    }

    async function interfaceResolver() {
        const { walletAddress } = await activateWallet_WithUSDCPaymaster();
        const walletContract = new ethers.Contract(
            walletAddress,
            SmartWallet__factory.abi,
            ethers.provider
        );

        const SUPPORT_INTERFACE_ID = "0x01ffc9a7";
        const ERC721_INTERFACE_ID = "0x150b7a02";
        const ERC1155_INTERFACE_ID = "0x4e2312e0";

        let support = await walletContract.supportsInterface(
            SUPPORT_INTERFACE_ID
        );
        expect(support).to.equal(true);
        support = await walletContract.supportsInterface(ERC721_INTERFACE_ID);
        expect(support).to.equal(true);
        support = await walletContract.supportsInterface(ERC1155_INTERFACE_ID);
        expect(support).to.equal(true);
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
        const walletContract = new ethers.Contract(walletAddress, SmartWallet__factory.abi, ethers.provider);

        // getVersion
        const version = await walletContract.getVersion();
        expect(version).to.equal(1);

    }


    describe("wallet test", async function () {
        it("activate wallet(ETH)", activateWallet_withETH);
        it("activate wallet(USDC)", activateWallet_WithUSDCPaymaster);
        it("update guardian", updateGuardian);
        it("recovery wallet", recoveryWallet);
        it("interface resolver", interfaceResolver);
        it("other coverage test", coverageTest);
    });



});