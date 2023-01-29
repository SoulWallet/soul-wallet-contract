"use strict";
/*
 * @Description:
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-08-05 16:08:23
 * @LastEditors: cejay
 * @LastEditTime: 2023-01-28 20:04:45
 */
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.UserOperation = exports.EIP4337Lib = void 0;
const utils_1 = require("ethers/lib/utils");
const address_1 = require("../defines/address");
const userOperation_1 = require("../entity/userOperation");
const soulWallet_1 = require("../contracts/soulWallet");
const walletProxy_1 = require("../contracts/walletProxy");
const decodeCallData_1 = require("../utils/decodeCallData");
const Guardian_1 = require("../utils/Guardian");
const Token_1 = require("../utils/Token");
const rpc_1 = require("../utils/rpc");
const converter_1 = require("../utils/converter");
const ethers_1 = require("ethers");
const gasFee_1 = require("../utils/gasFee");
const tokenAndPaymaster_1 = require("../utils/tokenAndPaymaster");
class EIP4337Lib {
    /**
     *
     * @param entryPointAddress the entryPoint address
     * @param ownerAddress the owner address
     * @param upgradeDelay the upgrade delay time
     * @param guardianDelay the guardian delay time
     * @param guardianAddress the guardian contract address
     * @param tokenAndPaymaster the packed token and paymaster (bytes)
     * @returns inithex
     */
    static getInitializeData(entryPointAddress, ownerAddress, upgradeDelay, guardianDelay, guardianAddress, tokenAndPaymaster) {
        // function initialize(IEntryPoint anEntryPoint, address anOwner,  IERC20 token,address paymaster)
        // encodeFunctionData
        let iface = new ethers_1.ethers.utils.Interface(soulWallet_1.SimpleWalletContract.ABI);
        let initializeData = iface.encodeFunctionData("initialize", [entryPointAddress, ownerAddress, upgradeDelay, guardianDelay, guardianAddress, tokenAndPaymaster]);
        return initializeData;
    }
    /**
     * get wallet code
     * @param walletLogicAddress the wallet logic contract address
     * @param entryPointAddress the entryPoint address
     * @param ownerAddress the owner address
     * @param upgradeDelay the upgrade delay time
     * @param guardianDelay the guardian delay time
     * @param guardianAddress the guardian contract address
     * @param tokenAndPaymaster the packed token and paymaster (bytes)
     * @returns the wallet code hex string
     */
    static getWalletCode(walletLogicAddress, entryPointAddress, ownerAddress, upgradeDelay, guardianDelay, guardianAddress, tokenAndPaymaster) {
        const initializeData = EIP4337Lib.getInitializeData(entryPointAddress, ownerAddress, upgradeDelay, guardianDelay, guardianAddress, tokenAndPaymaster);
        const factory = new ethers_1.ethers.ContractFactory(walletProxy_1.WalletProxyContract.ABI, walletProxy_1.WalletProxyContract.bytecode);
        const walletBytecode = factory.getDeployTransaction(walletLogicAddress, initializeData).data;
        return walletBytecode;
    }
    /**
     * calculate wallet address by owner address
     * @param walletLogicAddress the wallet logic contract address
     * @param entryPointAddress the entryPoint address
     * @param ownerAddress the owner address
     * @param upgradeDelay the upgrade delay time
     * @param guardianDelay the guardian delay time
     * @param guardianAddress the guardian contract address
     * @param tokenAndPaymaster the packed token and paymaster (bytes)
     * @param salt the salt number,default is 0
     * @param create2Factory create2factory address defined in EIP-2470
     * @returns
     */
    static calculateWalletAddress(walletLogicAddress, entryPointAddress, ownerAddress, upgradeDelay, guardianDelay, guardianAddress, tokenAndPaymaster, salt, create2Factory) {
        const initCodeWithArgs = EIP4337Lib.getWalletCode(walletLogicAddress, entryPointAddress, ownerAddress, upgradeDelay, guardianDelay, guardianAddress, tokenAndPaymaster);
        const initCodeHash = (0, utils_1.keccak256)(initCodeWithArgs);
        const walletAddress = EIP4337Lib.calculateWalletAddressByCodeHash(initCodeHash, salt, create2Factory);
        return walletAddress;
    }
    /**
     * get the userOperation for active (first time) the wallet
     * @param walletLogicAddress the wallet logic contract address
     * @param entryPointAddress
     * @param payMasterAddress
     * @param ownerAddress
     * @param upgradeDelay the upgrade delay time
     * @param guardianDelay the guardian delay time
     * @param guardianAddress the guardian contract address
     * @param tokenAndPaymaster the packed token and paymaster (bytes)
     * @param payMasterAddress the paymaster address
     * @param salt the salt number,default is 0
     * @param create2Factory create2factory address
     * @param maxFeePerGas the max fee per gas
     * @param maxPriorityFeePerGas the max priority fee per gas
     */
    static activateWalletOp(walletLogicAddress, entryPointAddress, ownerAddress, upgradeDelay, guardianDelay, guardianAddress, tokenAndPaymaster, payMasterAddress, salt, create2Factory, maxFeePerGas, maxPriorityFeePerGas) {
        const initCodeWithArgs = EIP4337Lib.getWalletCode(walletLogicAddress, entryPointAddress, ownerAddress, upgradeDelay, guardianDelay, guardianAddress, tokenAndPaymaster);
        const initCodeHash = (0, utils_1.keccak256)(initCodeWithArgs);
        const walletAddress = EIP4337Lib.calculateWalletAddressByCodeHash(initCodeHash, salt, create2Factory);
        let userOperation = new userOperation_1.UserOperation();
        userOperation.nonce = 0;
        userOperation.sender = walletAddress;
        userOperation.paymasterAndData = payMasterAddress;
        userOperation.maxFeePerGas = maxFeePerGas;
        userOperation.maxPriorityFeePerGas = maxPriorityFeePerGas;
        userOperation.initCode = EIP4337Lib.getPackedInitCode(create2Factory, initCodeWithArgs, salt);
        userOperation.verificationGasLimit = 500000; //100000 + 3200 + 200 * userOperation.initCode.length;
        userOperation.callGasLimit = 0;
        userOperation.callData = "0x";
        return userOperation;
    }
    static getPackedInitCode(create2Factory, initCode, salt) {
        const abi = { "inputs": [{ "internalType": "bytes", "name": "_initCode", "type": "bytes" }, { "internalType": "bytes32", "name": "_salt", "type": "bytes32" }], "name": "deploy", "outputs": [{ "internalType": "address payable", "name": "createdContract", "type": "address" }], "stateMutability": "nonpayable", "type": "function" };
        let iface = new ethers_1.ethers.utils.Interface([abi]);
        let packedInitCode = iface.encodeFunctionData("deploy", [initCode, EIP4337Lib.number2Bytes32(salt)]).substring(2);
        return create2Factory.toLowerCase() + packedInitCode;
    }
    /**
     * calculate EIP-4337 wallet address
     * @param initContract the init Contract
     * @param initArgs the init args
     * @param salt the salt number
     * @param create2Factory create2factory address defined in EIP-2470
     * @returns
     */
    static calculateWalletAddressByCode(initContract, initArgs, salt, create2Factory) {
        const factory = new ethers_1.ethers.ContractFactory(initContract.ABI, initContract.bytecode);
        const initCodeWithArgs = factory.getDeployTransaction(initArgs).data;
        const initCodeHash = (0, utils_1.keccak256)(initCodeWithArgs);
        return EIP4337Lib.calculateWalletAddressByCodeHash(initCodeHash, salt, create2Factory);
    }
    static number2Bytes32(num) {
        return (0, utils_1.hexZeroPad)((0, utils_1.hexlify)(num), 32);
    }
    /**
     * calculate EIP-4337 wallet address
     * @param initCodeHash the init code after keccak256
     * @param salt the salt number
     * @param create2Factory create2factory address defined in EIP-2470
     * @returns the EIP-4337 wallet address
     */
    static calculateWalletAddressByCodeHash(initCodeHash, salt, create2Factory) {
        return (0, utils_1.getCreate2Address)(create2Factory, EIP4337Lib.number2Bytes32(salt), initCodeHash);
    }
    /**
     * get nonce number from contract wallet
     * @param walletAddress the wallet address
     * @param web3 the web3 instance
     * @param defaultBlock "earliest", "latest" and "pending"
     * @returns the next nonce number
     */
    static getNonce(walletAddress, etherProvider, defaultBlock = 'latest') {
        return __awaiter(this, void 0, void 0, function* () {
            try {
                const code = yield etherProvider.getCode(walletAddress, defaultBlock);
                // check contract is exist
                if (code === '0x') {
                    return 0;
                }
                else {
                    const contract = new ethers_1.ethers.Contract(walletAddress, [{ "inputs": [], "name": "nonce", "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }], "stateMutability": "view", "type": "function" }], etherProvider);
                    const nonce = yield contract.nonce();
                    // try parse to number
                    const nextNonce = parseInt(nonce, 10);
                    if (isNaN(nextNonce)) {
                        throw new Error('nonce is not a number');
                    }
                    return nextNonce;
                }
            }
            catch (error) {
                throw error;
            }
        });
    }
}
exports.EIP4337Lib = EIP4337Lib;
EIP4337Lib.Utils = {
    getNonce: EIP4337Lib.getNonce,
    DecodeCallData: decodeCallData_1.DecodeCallData,
    fromTransaction: converter_1.Converter.fromTransaction,
    suggestedGasFee: gasFee_1.CodefiGasFees,
    tokenAndPaymaster: tokenAndPaymaster_1.TokenAndPaymaster
};
EIP4337Lib.Defines = {
    AddressZero: address_1.AddressZero
};
EIP4337Lib.Guaridian = Guardian_1.Guaridian;
EIP4337Lib.Tokens = {
    ERC20: Token_1.ERC20,
    ERC721: Token_1.ERC721,
    ERC1155: Token_1.ERC1155,
    ETH: Token_1.ETH,
};
EIP4337Lib.RPC = {
    eth_sendUserOperation: rpc_1.RPC.eth_sendUserOperation,
    eth_supportedEntryPoints: rpc_1.RPC.eth_supportedEntryPoints,
    waitUserOperation: rpc_1.RPC.waitUserOperation,
    simulateValidation: rpc_1.RPC.simulateValidation,
    simulateHandleOp: rpc_1.RPC.simulateHandleOp,
};
var userOperation_2 = require("../entity/userOperation");
Object.defineProperty(exports, "UserOperation", { enumerable: true, get: function () { return userOperation_2.UserOperation; } });
//# sourceMappingURL=EIP4337Lib.js.map