/*
 * @Description: 
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-12-24 14:24:47
 * @LastEditors: cejay
 * @LastEditTime: 2023-01-29 17:25:34
 */
import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers, network } from "hardhat";
import { EIP4337Lib, UserOperation, ITokenAndPaymaster } from 'soul-wallet-lib';
import { SmartWallet__factory } from "../src/types/index";
import { Utils } from "./Utils";
import fs from 'fs';

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

        // #region WETH
        const _weth_abi = [
            {
                "constant": true,
                "inputs": [],
                "name": "name",
                "outputs": [
                    {
                        "name": "",
                        "type": "string"
                    }
                ],
                "payable": false,
                "stateMutability": "view",
                "type": "function"
            },
            {
                "constant": false,
                "inputs": [
                    {
                        "name": "guy",
                        "type": "address"
                    },
                    {
                        "name": "wad",
                        "type": "uint256"
                    }
                ],
                "name": "approve",
                "outputs": [
                    {
                        "name": "",
                        "type": "bool"
                    }
                ],
                "payable": false,
                "stateMutability": "nonpayable",
                "type": "function"
            },
            {
                "constant": true,
                "inputs": [],
                "name": "totalSupply",
                "outputs": [
                    {
                        "name": "",
                        "type": "uint256"
                    }
                ],
                "payable": false,
                "stateMutability": "view",
                "type": "function"
            },
            {
                "constant": false,
                "inputs": [
                    {
                        "name": "src",
                        "type": "address"
                    },
                    {
                        "name": "dst",
                        "type": "address"
                    },
                    {
                        "name": "wad",
                        "type": "uint256"
                    }
                ],
                "name": "transferFrom",
                "outputs": [
                    {
                        "name": "",
                        "type": "bool"
                    }
                ],
                "payable": false,
                "stateMutability": "nonpayable",
                "type": "function"
            },
            {
                "constant": false,
                "inputs": [
                    {
                        "name": "wad",
                        "type": "uint256"
                    }
                ],
                "name": "withdraw",
                "outputs": [],
                "payable": false,
                "stateMutability": "nonpayable",
                "type": "function"
            },
            {
                "constant": true,
                "inputs": [],
                "name": "decimals",
                "outputs": [
                    {
                        "name": "",
                        "type": "uint8"
                    }
                ],
                "payable": false,
                "stateMutability": "view",
                "type": "function"
            },
            {
                "constant": true,
                "inputs": [
                    {
                        "name": "",
                        "type": "address"
                    }
                ],
                "name": "balanceOf",
                "outputs": [
                    {
                        "name": "",
                        "type": "uint256"
                    }
                ],
                "payable": false,
                "stateMutability": "view",
                "type": "function"
            },
            {
                "constant": true,
                "inputs": [],
                "name": "symbol",
                "outputs": [
                    {
                        "name": "",
                        "type": "string"
                    }
                ],
                "payable": false,
                "stateMutability": "view",
                "type": "function"
            },
            {
                "constant": false,
                "inputs": [
                    {
                        "name": "dst",
                        "type": "address"
                    },
                    {
                        "name": "wad",
                        "type": "uint256"
                    }
                ],
                "name": "transfer",
                "outputs": [
                    {
                        "name": "",
                        "type": "bool"
                    }
                ],
                "payable": false,
                "stateMutability": "nonpayable",
                "type": "function"
            },
            {
                "constant": false,
                "inputs": [],
                "name": "deposit",
                "outputs": [],
                "payable": true,
                "stateMutability": "payable",
                "type": "function"
            },
            {
                "constant": true,
                "inputs": [
                    {
                        "name": "",
                        "type": "address"
                    },
                    {
                        "name": "",
                        "type": "address"
                    }
                ],
                "name": "allowance",
                "outputs": [
                    {
                        "name": "",
                        "type": "uint256"
                    }
                ],
                "payable": false,
                "stateMutability": "view",
                "type": "function"
            },
            {
                "payable": true,
                "stateMutability": "payable",
                "type": "fallback"
            },
            {
                "anonymous": false,
                "inputs": [
                    {
                        "indexed": true,
                        "name": "src",
                        "type": "address"
                    },
                    {
                        "indexed": true,
                        "name": "guy",
                        "type": "address"
                    },
                    {
                        "indexed": false,
                        "name": "wad",
                        "type": "uint256"
                    }
                ],
                "name": "Approval",
                "type": "event"
            },
            {
                "anonymous": false,
                "inputs": [
                    {
                        "indexed": true,
                        "name": "src",
                        "type": "address"
                    },
                    {
                        "indexed": true,
                        "name": "dst",
                        "type": "address"
                    },
                    {
                        "indexed": false,
                        "name": "wad",
                        "type": "uint256"
                    }
                ],
                "name": "Transfer",
                "type": "event"
            },
            {
                "anonymous": false,
                "inputs": [
                    {
                        "indexed": true,
                        "name": "dst",
                        "type": "address"
                    },
                    {
                        "indexed": false,
                        "name": "wad",
                        "type": "uint256"
                    }
                ],
                "name": "Deposit",
                "type": "event"
            },
            {
                "anonymous": false,
                "inputs": [
                    {
                        "indexed": true,
                        "name": "src",
                        "type": "address"
                    },
                    {
                        "indexed": false,
                        "name": "wad",
                        "type": "uint256"
                    }
                ],
                "name": "Withdrawal",
                "type": "event"
            }
        ];
        const _weth_bytecode = '0x606060405260408051908101604052600d81527f57726170706564204574686572000000000000000000000000000000000000006020820152600090805161004b9291602001906100b1565b5060408051908101604052600481527f5745544800000000000000000000000000000000000000000000000000000000602082015260019080516100939291602001906100b1565b506002805460ff1916601217905534156100ac57600080fd5b61014c565b828054600181600116156101000203166002900490600052602060002090601f016020900481019282601f106100f257805160ff191683800117855561011f565b8280016001018555821561011f579182015b8281111561011f578251825591602001919060010190610104565b5061012b92915061012f565b5090565b61014991905b8082111561012b5760008155600101610135565b90565b6106a98061015b6000396000f3006060604052600436106100955763ffffffff60e060020a60003504166306fdde03811461009f578063095ea7b31461012957806318160ddd1461015f57806323b872dd146101845780632e1a7d4d146101ac578063313ce567146101c257806370a08231146101eb57806395d89b411461020a578063a9059cbb1461021d578063d0e30db014610095578063dd62ed3e1461023f575b61009d610264565b005b34156100aa57600080fd5b6100b26102ba565b60405160208082528190810183818151815260200191508051906020019080838360005b838110156100ee5780820151838201526020016100d6565b50505050905090810190601f16801561011b5780820380516001836020036101000a031916815260200191505b509250505060405180910390f35b341561013457600080fd5b61014b600160a060020a0360043516602435610358565b604051901515815260200160405180910390f35b341561016a57600080fd5b6101726103c4565b60405190815260200160405180910390f35b341561018f57600080fd5b61014b600160a060020a03600435811690602435166044356103d2565b34156101b757600080fd5b61009d600435610518565b34156101cd57600080fd5b6101d56105c6565b60405160ff909116815260200160405180910390f35b34156101f657600080fd5b610172600160a060020a03600435166105cf565b341561021557600080fd5b6100b26105e1565b341561022857600080fd5b61014b600160a060020a036004351660243561064c565b341561024a57600080fd5b610172600160a060020a0360043581169060243516610660565b600160a060020a033316600081815260036020526040908190208054349081019091557fe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c915190815260200160405180910390a2565b60008054600181600116156101000203166002900480601f0160208091040260200160405190810160405280929190818152602001828054600181600116156101000203166002900480156103505780601f1061032557610100808354040283529160200191610350565b820191906000526020600020905b81548152906001019060200180831161033357829003601f168201915b505050505081565b600160a060020a03338116600081815260046020908152604080832094871680845294909152808220859055909291907f8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b9259085905190815260200160405180910390a350600192915050565b600160a060020a0330163190565b600160a060020a038316600090815260036020526040812054829010156103f857600080fd5b33600160a060020a031684600160a060020a0316141580156104425750600160a060020a038085166000908152600460209081526040808320339094168352929052205460001914155b156104a957600160a060020a03808516600090815260046020908152604080832033909416835292905220548290101561047b57600080fd5b600160a060020a03808516600090815260046020908152604080832033909416835292905220805483900390555b600160a060020a038085166000818152600360205260408082208054879003905592861680825290839020805486019055917fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef9085905190815260200160405180910390a35060019392505050565b600160a060020a0333166000908152600360205260409020548190101561053e57600080fd5b600160a060020a033316600081815260036020526040908190208054849003905582156108fc0290839051600060405180830381858888f19350505050151561058657600080fd5b33600160a060020a03167f7fcf532c15f0a6db0bd6d0e038bea71d30d808c7d98cb3bf7268a95bf5081b658260405190815260200160405180910390a250565b60025460ff1681565b60036020526000908152604090205481565b60018054600181600116156101000203166002900480601f0160208091040260200160405190810160405280929190818152602001828054600181600116156101000203166002900480156103505780601f1061032557610100808354040283529160200191610350565b60006106593384846103d2565b9392505050565b6004602090815260009283526040808420909152908252902054815600a165627a7a72305820ddedfb0ba7e4ed5e2c335eb9d42541173b86cda8a54f6c59663d43605e3dfc040029';
        const WETH = {
            contract: await new ethers.ContractFactory(_weth_abi, _weth_bytecode, accounts[0]).deploy(),
            abi: _weth_abi
        };
        log("WETH:", WETH.contract.address);

        // #endregion

        // #region WETHPaymaster
        const WETHPaymaster = {
            contract: await (await ethers.getContractFactory("WETHPaymaster")).deploy(
                EntryPoint.contract.address,
                WETH.contract.address,
                accounts[0].address
            )
        };
        // addKnownWalletLogic
        await WETHPaymaster.contract.addKnownWalletLogic([SoulWalletLogicCodeHash]);

        const _paymasterStake = '' + Math.pow(10, 17);
        await WETHPaymaster.contract.addStake(
            1, {
            from: accounts[0].address,
            value: _paymasterStake
        });
        await WETHPaymaster.contract.deposit({
            from: accounts[0].address,
            value: _paymasterStake
        });
        log("WETHPaymaster:", WETHPaymaster.contract.address);

        // #endregion WETHPaymaster

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
            WETH,
            WETHPaymaster,
            GuardianLogic
        };
    }

    async function activateWallet() {
        //describe("activate wallet", async () => {
        const { chainId, accounts, SingletonFactory, walletOwner, SoulWalletLogic, EntryPoint, WETH, WETHPaymaster, GuardianLogic } = await loadFixture(deployFixture);

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
        const gurdianAddressAndInitCode = EIP4337Lib.Guaridian.calculateGuardianAndInitCode(GuardianLogic.contract.address, guardiansAddress, Math.round(guardiansAddress.length / 2), guardianSalt, SingletonFactory);
        log('guardian address ==> ' + gurdianAddressAndInitCode.address);
        {
            // test guardian order (For user experience, guardian cannot rely on the order of address)
            const _guardiansAddress = [...guardiansAddress];
            const _guardianTmpItem = _guardiansAddress[0];
            _guardiansAddress[0] = _guardiansAddress[1];
            _guardiansAddress[1] = _guardianTmpItem;

            const gurdianAddressAndInitCode = EIP4337Lib.Guaridian.calculateGuardianAndInitCode(GuardianLogic.contract.address, _guardiansAddress, Math.round(guardiansAddress.length / 2), guardianSalt, SingletonFactory);
            expect(gurdianAddressAndInitCode.address).to.equal(gurdianAddressAndInitCode.address);

        }

        const tokenAndPaymaster = [
            {
                token: WETH.contract.address,
                paymaster: WETHPaymaster.contract.address
            }
        ];
        const packedTokenAndPaymaster = EIP4337Lib.Utils.tokenAndPaymaster.pack(tokenAndPaymaster);

        const walletAddress = await EIP4337Lib.calculateWalletAddress(
            SoulWalletLogic.contract.address,
            EntryPoint.contract.address,
            walletOwner.address,
            upgradeDelay,
            guardianDelay,
            gurdianAddressAndInitCode.address,
            packedTokenAndPaymaster,
            0,
            SingletonFactory
        );

        log('walletAddress: ' + walletAddress);

        //#region swap eth to weth
        // account[0] send 1 eth to WEthAddress

        await WETH.contract.deposit({
            from: accounts[0].address,
            value: ethers.utils.parseEther("1")
        });


        // get balance of weth 
        let wethBalance = await WETH.contract.balanceOf(accounts[0].address);
        log('wethBalance: ' + ethers.utils.formatEther(wethBalance), 'WETH');
        // #endregion

        // send 0.01 weth to wallet
        await WETH.contract.transfer(walletAddress, ethers.utils.parseEther('0.01'));
        // get balance of weth
        wethBalance = await WETH.contract.balanceOf(walletAddress);
        log('wethBalance: ' + ethers.utils.formatEther(wethBalance), 'WETH');
        expect(ethers.utils.formatEther(wethBalance)).to.equal('0.01'); // 0.01 WETH

        const activateOp = EIP4337Lib.activateWalletOp(
            SoulWalletLogic.contract.address,
            EntryPoint.contract.address,
            walletOwner.address,
            upgradeDelay,
            guardianDelay,
            gurdianAddressAndInitCode.address,
            packedTokenAndPaymaster,
            WETHPaymaster.contract.address,
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
        let guardianInfo = await EIP4337Lib.Guaridian.getGuardian(ethers.provider, walletAddress);

        expect(guardianInfo?.currentGuardian).to.equal(gurdianAddressAndInitCode.address);

        return {
            chainId, accounts, GuardianLogic, SingletonFactory, EntryPoint, WETHPaymaster,

            walletAddress,
            walletOwner,
            guardian: gurdianAddressAndInitCode.address,
            guardianInitcode: gurdianAddressAndInitCode.initCode,
            guardians,
            guardianSalt,
            guardianDelay,

            WETH

        };
    }

    async function updateGuardian() {
        const { walletAddress, walletOwner, guardian, guardianDelay, chainId, accounts, GuardianLogic, SingletonFactory, EntryPoint, WETHPaymaster } = await activateWallet();
        let guardianInfo = await EIP4337Lib.Guaridian.getGuardian(ethers.provider, walletAddress);

        expect(guardianInfo?.currentGuardian).to.equal(guardian);
        const guardians: string[] = [];
        for (let i = 0; i < accounts.length; i++) {
            guardians.push(accounts[i].address);
        }
        const guardianSalt = 'saltText' + Math.random();
        const gurdianAddressAndInitCode = EIP4337Lib.Guaridian.calculateGuardianAndInitCode(GuardianLogic.contract.address, guardians, Math.round(guardians.length / 2), guardianSalt, SingletonFactory);
        log('new guardian address ==> ' + gurdianAddressAndInitCode.address);
        const nonce = await EIP4337Lib.Utils.getNonce(walletAddress, ethers.provider);

        const setGuardianOP = await EIP4337Lib.Guaridian.setGuardian(
            ethers.provider,
            walletAddress,
            gurdianAddressAndInitCode.address,
            nonce,
            EntryPoint.contract.address,
            WETHPaymaster.contract.address,
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
        guardianInfo = await EIP4337Lib.Guaridian.getGuardian(ethers.provider, walletAddress);
        expect(guardianInfo?.currentGuardian).to.equal(guardian);
        // wait block for guardianDelay 
        await time.increaseTo((await time.latest()) + guardianDelay);
        guardianInfo = await EIP4337Lib.Guaridian.getGuardian(ethers.provider, walletAddress, await time.latest());
        expect(guardianInfo?.currentGuardian).to.equal(gurdianAddressAndInitCode.address);

    }

    async function recoveryWallet() {
        const { WETH, guardians, guardianSalt, guardianInitcode, walletAddress, walletOwner, guardian, guardianDelay, chainId, accounts, GuardianLogic, SingletonFactory, EntryPoint, WETHPaymaster } = await activateWallet();
        let guardianInfo = await EIP4337Lib.Guaridian.getGuardian(ethers.provider, walletAddress);
        expect(guardianInfo?.currentGuardian).to.equal(guardian);

        const nonce = await EIP4337Lib.Utils.getNonce(walletAddress, ethers.provider);

        const newWalletOwner = await ethers.Wallet.createRandom();
        const transferOwnerOP = await EIP4337Lib.Guaridian.transferOwner(
            ethers.provider,
            walletAddress,
            nonce,
            EntryPoint.contract.address,
            WETHPaymaster.contract.address,
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
        const { walletAddress } = await activateWallet();
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


    async function stakeETH() {
        const { walletAddress, walletOwner, guardian, guardianDelay, chainId, accounts, GuardianLogic, SingletonFactory, EntryPoint, WETH } = await activateWallet();
        await EntryPoint.contract.depositTo(walletAddress, {
            from: accounts[0].address,
            value: ethers.utils.parseEther('1')
        });
        const depositInfo = await EntryPoint.contract.getDepositInfo(walletAddress);
        expect(depositInfo.deposit).to.equal(ethers.utils.parseEther('1'));
        // send transaction direct pay gas fee
        let nonce = await EIP4337Lib.Utils.getNonce(walletAddress, ethers.provider);
        // get balance before send(ERC20:WETH.contract.address)
        const balanceBefore = await WETH.contract.balanceOf(walletAddress);
        const sendETHOp = await EIP4337Lib.Tokens.ERC20.transfer(
            ethers.provider,
            walletAddress,
            nonce, EntryPoint.contract.address,
            EIP4337Lib.Defines.AddressZero,
            10000000000, 10000000000,
            WETH.contract.address,
            accounts[0].address,
            ethers.utils.parseEther('0.001').toString()
        );
        if (!sendETHOp) {
            throw new Error('sendETHOp is null');
        }
        const sendETHOpuserOpHash = sendETHOp.getUserOpHash(EntryPoint.contract.address, chainId);
        const sendETHOpSignature = Utils.signMessage(sendETHOpuserOpHash, walletOwner.privateKey)
        sendETHOp.signWithSignature(walletOwner.address, sendETHOpSignature);
        await EntryPoint.contract.handleOps([sendETHOp], accounts[0].address);
        // get balance after send(ERC20:WETH.contract.address)
        const balanceAfter = await WETH.contract.balanceOf(walletAddress);
        expect(balanceBefore.sub(balanceAfter).toString()).to.equal(ethers.utils.parseEther('0.001').toString());


        // withdrawDepositTo
        const transaction = {
            data: new ethers.utils.Interface([
                {
                    "inputs": [
                        {
                            "internalType": "address payable",
                            "name": "withdrawAddress",
                            "type": "address"
                        },
                        {
                            "internalType": "uint256",
                            "name": "amount",
                            "type": "uint256"
                        }
                    ],
                    "name": "withdrawDepositTo",
                    "outputs": [],
                    "stateMutability": "nonpayable",
                    "type": "function"
                }
            ]).encodeFunctionData("withdrawDepositTo", [
                accounts[0].address,
                ethers.utils.parseEther('0.1').toString()
            ]),
            from: walletAddress,
            gas: 60000 .toString(16),
            to: walletAddress,
            value: '0'
        };

        const gas = await ethers.provider.estimateGas(transaction);
        log(`gas:`, gas.toString());

        nonce = await EIP4337Lib.Utils.getNonce(walletAddress, ethers.provider);

        const withdrawDepositToOp = await EIP4337Lib.Utils.fromTransaction(
            ethers.provider,
            EntryPoint.contract.address,
            transaction,
            nonce,
            10000000000, 10000000000,
            EIP4337Lib.Defines.AddressZero,
        );

        if (!withdrawDepositToOp) {
            throw new Error('withdrawDepositToOp is null');
        }
        const withdrawDepositToOpuserOpHash = withdrawDepositToOp.getUserOpHash(EntryPoint.contract.address, chainId);
        const withdrawDepositToOpSignature = Utils.signMessage(withdrawDepositToOpuserOpHash, walletOwner.privateKey)
        withdrawDepositToOp.signWithSignature(walletOwner.address, withdrawDepositToOpSignature);
        await EIP4337Lib.RPC.simulateHandleOp(ethers.provider, EntryPoint.contract.address, withdrawDepositToOp);
        // get balanceOf before withdrawDepositTo
        const balanceOfBefore = await EntryPoint.contract.balanceOf(walletAddress);
        await EntryPoint.contract.handleOps([withdrawDepositToOp], accounts[0].address);
        // get balanceOf after withdrawDepositTo
        const balanceOfAfter = await EntryPoint.contract.balanceOf(walletAddress);
        const gasFee = balanceOfBefore.sub(balanceOfAfter).sub(ethers.utils.parseEther('0.1'));
        expect(gasFee.toNumber() > 0).to.equal(true);



    }

    async function coverageTest() {
        const { walletAddress, walletOwner, guardian, guardianDelay, chainId, accounts, GuardianLogic, SingletonFactory, EntryPoint, WETH } = await activateWallet();
        const walletContract = new ethers.Contract(walletAddress, SmartWallet__factory.abi, ethers.provider);

        // getVersion
        const version = await walletContract.getVersion();
        expect(version).to.equal(1);

    }


    describe("wallet test", async function () {
        it("activate wallet", activateWallet);
        it("update guardian", updateGuardian);
        it("recovery wallet", recoveryWallet);
        it("interface resolver", interfaceResolver);
        it("stake ETH direct pay gas fee", stakeETH);
        it("other coverage test", coverageTest);
    });



});
