/*
 * @Description: 
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-12-24 14:24:47
 * @LastEditors: cejay
 * @LastEditTime: 2023-02-01 16:02:05
 */
import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers, network } from "hardhat";
import { EIP4337Lib, UserOperation } from 'soul-wallet-lib';
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

        let SingletonFactory = '0xce0042B868300000d44A59004Da54A005ffdcf9f';
        // if network is hardhat
        if (network.name === "hardhat") {
            SingletonFactory = (await (await ethers.getContractFactory("SingletonFactory")).deploy()).address;
        } else {
            const code = await ethers.provider.getCode(SingletonFactory);
            if (code === '0x') {
                // send 0.0247 ETH to SingletonFactory
                await accounts[0].sendTransaction({
                    to: SingletonFactory,
                    value: ethers.utils.parseEther("0.247"),
                });
                // get balance of SingletonFactory
                const balance = await ethers.provider.getBalance(SingletonFactory);
                expect(ethers.utils.formatEther(balance)).to.equal("0.247");
                await ethers.provider.send("eth_sendRawTransaction", [
                    "0xf9016c8085174876e8008303c4d88080b90154608060405234801561001057600080fd5b50610134806100206000396000f3fe6080604052348015600f57600080fd5b506004361060285760003560e01c80634af63f0214602d575b600080fd5b60cf60048036036040811015604157600080fd5b810190602081018135640100000000811115605b57600080fd5b820183602082011115606c57600080fd5b80359060200191846001830284011164010000000083111715608d57600080fd5b91908080601f016020809104026020016040519081016040528093929190818152602001838380828437600092019190915250929550509135925060eb915050565b604080516001600160a01b039092168252519081900360200190f35b6000818351602085016000f5939250505056fea26469706673582212206b44f8a82cb6b156bfcc3dc6aadd6df4eefd204bc928a4397fd15dacf6d5320564736f6c634300060200331b83247000822470"
                ]);
                expect(await ethers.provider.getCode(SingletonFactory)).to.not.equal('0x');
            }
        }


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

        // #endregion

        // #region USDCPriceFeed
        const USDCPriceFeed = {
            contract: await (await ethers.getContractFactory("USDCPriceFeed")).deploy()
        };
        // #endregion

        // #region USDCPaymaster
        const USDCPaymaster = {
            contract: await (await ethers.getContractFactory("USDCPaymaster")).deploy(
                EntryPoint.contract.address,
                USDC.contract.address,
                USDCPriceFeed.contract.address,
                accounts[0].address
            )
        };
        // addKnownWalletLogic
        await USDCPaymaster.contract.addKnownWalletLogic([SoulWalletLogicCodeHash]);

        const _paymasterStake = '' + Math.pow(10, 17);
        await USDCPaymaster.contract.addStake(
            1, {
            from: accounts[0].address,
            value: _paymasterStake
        });
        await USDCPaymaster.contract.deposit({
            from: accounts[0].address,
            value: _paymasterStake
        });
        log("USDCPaymaster:", USDCPaymaster.contract.address);

        // #endregion USDCPaymaster

        // #region guardian logic

        const GuardianLogic = {
            contract: await (await ethers.getContractFactory("GuardianMultiSigWallet")).deploy()
        }
        log("GuardianLogic:", GuardianLogic.contract.address);

        // #endregion

        return {
            chainId,
            accounts,
            walletOwner,
            SingletonFactory,
            SoulWalletLogic,
            EntryPoint,
            USDC,
            USDCPaymaster,
            GuardianLogic,
            USDCPriceFeed
        };
    }

    async function activateWallet_withETH() {
        //describe("activate wallet", async () => {
        const { chainId, accounts, SingletonFactory, walletOwner, SoulWalletLogic, EntryPoint, USDC, USDCPaymaster, GuardianLogic } = await loadFixture(deployFixture);

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
        const gurdianAddressAndInitCode = EIP4337Lib.Guardian.calculateGuardianAndInitCode(GuardianLogic.contract.address, guardiansAddress, Math.round(guardiansAddress.length / 2), guardianSalt, SingletonFactory);
        log('guardian address ==> ' + gurdianAddressAndInitCode.address);
        {
            // test guardian order (For user experience, guardian cannot rely on the order of address)
            const _guardiansAddress = [...guardiansAddress];
            const _guardianTmpItem = _guardiansAddress[0];
            _guardiansAddress[0] = _guardiansAddress[1];
            _guardiansAddress[1] = _guardianTmpItem;

            const gurdianAddressAndInitCode = EIP4337Lib.Guardian.calculateGuardianAndInitCode(GuardianLogic.contract.address, _guardiansAddress, Math.round(guardiansAddress.length / 2), guardianSalt, SingletonFactory);
            expect(gurdianAddressAndInitCode.address).to.equal(gurdianAddressAndInitCode.address);

        }

        const walletAddress = await EIP4337Lib.calculateWalletAddress(
            SoulWalletLogic.contract.address,
            EntryPoint.contract.address,
            walletOwner.address,
            upgradeDelay,
            guardianDelay,
            gurdianAddressAndInitCode.address,
            0,
            SingletonFactory
        );

        log('walletAddress: ' + walletAddress);

        //#region

        // send 1 eth to wallet
        await accounts[0].sendTransaction({
            to: walletAddress,
            value: ethers.utils.parseEther('1')
        });
        // get balance of walletaddress
        const balance = await ethers.provider.getBalance(walletAddress);
        log('balance: ' + balance, 'wei');
        //expect(balance).to.gte(ethers.utils.parseEther('1'));

        const activateOp = EIP4337Lib.activateWalletOp(
            SoulWalletLogic.contract.address,
            EntryPoint.contract.address,
            walletOwner.address,
            upgradeDelay,
            guardianDelay,
            gurdianAddressAndInitCode.address,
            '0x',
            0,
            SingletonFactory,
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
        activateOp.signWithSignature(
            walletOwner.address,
            Utils.signMessage(userOpHash, walletOwner.privateKey)
        );
        const simulate = await EIP4337Lib.RPC.simulateHandleOp(ethers.provider, EntryPoint.contract.address, activateOp);
        log(`simulateHandleOp result:`, simulate);
        await EntryPoint.contract.handleOps([activateOp], accounts[0].address);
        const code = await ethers.provider.getCode(walletAddress);
        expect(code).to.not.equal('0x');
        let guardianInfo = await EIP4337Lib.Guardian.getGuardian(ethers.provider, walletAddress);

        expect(guardianInfo?.currentGuardian).to.equal(gurdianAddressAndInitCode.address);

        return {
            chainId, accounts, GuardianLogic, SingletonFactory, EntryPoint, USDCPaymaster,

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
        const { chainId, accounts, SingletonFactory, walletOwner, SoulWalletLogic, EntryPoint, USDC, USDCPaymaster, GuardianLogic } = await loadFixture(deployFixture);

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
        const gurdianAddressAndInitCode = EIP4337Lib.Guardian.calculateGuardianAndInitCode(GuardianLogic.contract.address, guardiansAddress, Math.round(guardiansAddress.length / 2), guardianSalt, SingletonFactory);
        log('guardian address ==> ' + gurdianAddressAndInitCode.address);
        {
            // test guardian order (For user experience, guardian cannot rely on the order of address)
            const _guardiansAddress = [...guardiansAddress];
            const _guardianTmpItem = _guardiansAddress[0];
            _guardiansAddress[0] = _guardiansAddress[1];
            _guardiansAddress[1] = _guardianTmpItem;

            const gurdianAddressAndInitCode = EIP4337Lib.Guardian.calculateGuardianAndInitCode(GuardianLogic.contract.address, _guardiansAddress, Math.round(guardiansAddress.length / 2), guardianSalt, SingletonFactory);
            expect(gurdianAddressAndInitCode.address).to.equal(gurdianAddressAndInitCode.address);

        }

        const walletAddress = await EIP4337Lib.calculateWalletAddress(
            SoulWalletLogic.contract.address,
            EntryPoint.contract.address,
            walletOwner.address,
            upgradeDelay,
            guardianDelay,
            gurdianAddressAndInitCode.address,
            0,
            SingletonFactory
        );

        log('walletAddress: ' + walletAddress);

        //#region

        // get balance of USDC 
        let usdcBalance = await USDC.contract.balanceOf(accounts[0].address);
        log('usdcBalance: ' + ethers.utils.formatEther(usdcBalance), 'USDC');
        // #endregion

        // send 0.01 USDC to wallet
        await USDC.contract.transfer(walletAddress, ethers.utils.parseEther('0.01'));
        // get balance of USDC
        usdcBalance = await USDC.contract.balanceOf(walletAddress);
        log('usdcBalance: ' + ethers.utils.formatEther(usdcBalance), 'USDC');
        expect(ethers.utils.formatEther(usdcBalance)).to.equal('0.01'); // 0.01 USDC
        const activateOp = EIP4337Lib.activateWalletOp(
            SoulWalletLogic.contract.address,
            EntryPoint.contract.address,
            walletOwner.address,
            upgradeDelay,
            guardianDelay,
            gurdianAddressAndInitCode.address,
            USDCPaymaster.contract.address,
            0,
            SingletonFactory,
            10000000000,// 100Gwei
            1000000000,// 10Gwei 
        );
        const approveCallData = await EIP4337Lib.Tokens.ERC20.getApproveCallData(ethers.provider, walletAddress, USDC.contract.address, USDCPaymaster.contract.address, 1e18.toString());
        activateOp.callData = approveCallData.callData;
        activateOp.callGasLimit = approveCallData.callGasLimit;



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
        activateOp.signWithSignature(
            walletOwner.address,
            Utils.signMessage(userOpHash, walletOwner.privateKey)
        );
        const simulate = await EIP4337Lib.RPC.simulateHandleOp(ethers.provider, EntryPoint.contract.address, activateOp);
        log(`simulateHandleOp result:`, simulate);
        await EntryPoint.contract.handleOps([activateOp], accounts[0].address);
        const code = await ethers.provider.getCode(walletAddress);
        expect(code).to.not.equal('0x');
        let guardianInfo = await EIP4337Lib.Guardian.getGuardian(ethers.provider, walletAddress);

        expect(guardianInfo?.currentGuardian).to.equal(gurdianAddressAndInitCode.address);

        return {
            chainId, accounts, GuardianLogic, SingletonFactory, EntryPoint, USDCPaymaster,

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
        const { walletAddress, walletOwner, guardian, guardianDelay, chainId, accounts, GuardianLogic, SingletonFactory, EntryPoint, USDCPaymaster } = await activateWallet_WithUSDCPaymaster();
        let guardianInfo = await EIP4337Lib.Guardian.getGuardian(ethers.provider, walletAddress);

        expect(guardianInfo?.currentGuardian).to.equal(guardian);
        const guardians: string[] = [];
        for (let i = 0; i < accounts.length; i++) {
            guardians.push(accounts[i].address);
        }
        const guardianSalt = 'saltText' + Math.random();
        const gurdianAddressAndInitCode = EIP4337Lib.Guardian.calculateGuardianAndInitCode(GuardianLogic.contract.address, guardians, Math.round(guardians.length / 2), guardianSalt, SingletonFactory);
        log('new guardian address ==> ' + gurdianAddressAndInitCode.address);
        const nonce = await EIP4337Lib.Utils.getNonce(walletAddress, ethers.provider);

        const setGuardianOP = await EIP4337Lib.Guardian.setGuardian(
            ethers.provider,
            walletAddress,
            gurdianAddressAndInitCode.address,
            nonce,
            EntryPoint.contract.address,
            USDCPaymaster.contract.address,
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
        guardianInfo = await EIP4337Lib.Guardian.getGuardian(ethers.provider, walletAddress);
        expect(guardianInfo?.currentGuardian).to.equal(guardian);
        // wait block for guardianDelay 
        await time.increaseTo((await time.latest()) + guardianDelay);
        guardianInfo = await EIP4337Lib.Guardian.getGuardian(ethers.provider, walletAddress, await time.latest());
        expect(guardianInfo?.currentGuardian).to.equal(gurdianAddressAndInitCode.address);

    }

    async function recoveryWallet() {
        const { USDC, guardians, guardianSalt, guardianInitcode, walletAddress, walletOwner, guardian, guardianDelay, chainId, accounts, GuardianLogic, SingletonFactory, EntryPoint, USDCPaymaster } = await activateWallet_WithUSDCPaymaster();
        let guardianInfo = await EIP4337Lib.Guardian.getGuardian(ethers.provider, walletAddress);
        expect(guardianInfo?.currentGuardian).to.equal(guardian);

        const nonce = await EIP4337Lib.Utils.getNonce(walletAddress, ethers.provider);

        const newWalletOwner = await ethers.Wallet.createRandom();
        const transferOwnerOP = await EIP4337Lib.Guardian.transferOwner(
            ethers.provider,
            walletAddress,
            nonce,
            EntryPoint.contract.address,
            USDCPaymaster.contract.address,
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
        transferOwnerOP.signWithGuardiansSign(guardian, guardianSignArr, 0, guardianInitcode);
        const simulate = await EIP4337Lib.RPC.simulateHandleOp(ethers.provider, EntryPoint.contract.address, transferOwnerOP);
        log(`simulateHandleOp result:`, simulate);
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
                EIP4337Lib.Defines.AddressZero,
                EIP4337Lib.Defines.AddressZero,
                0,
                0,
                "0x"
            )
        ).to.be.eq("0xf23a6e61");
        await expect(
            await walletContract.callStatic.onERC1155BatchReceived(
                EIP4337Lib.Defines.AddressZero,
                EIP4337Lib.Defines.AddressZero,
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
