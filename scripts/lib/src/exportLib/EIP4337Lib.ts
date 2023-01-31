/*
 * @Description: 
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-08-05 16:08:23
 * @LastEditors: cejay
 * @LastEditTime: 2023-01-28 20:04:45
 */

import { getCreate2Address, hexlify, hexZeroPad, keccak256 } from "ethers/lib/utils";
import { AddressZero } from "../defines/address";
import { UserOperation } from "../entity/userOperation";
import { IContract } from "../contracts/icontract";
import { SimpleWalletContract } from "../contracts/soulWallet";
import { WalletProxyContract } from "../contracts/walletProxy";
import { DecodeCallData } from '../utils/decodeCallData';
import { Guaridian } from "../utils/Guardian";
import { ERC1155, ERC20, ERC721, ETH } from "../utils/Token";
import { RPC } from '../utils/rpc';
import { Converter } from "../utils/converter";
import { ethers } from "ethers";
import { NumberLike } from "../defines/numberLike";
import { CodefiGasFees } from '../utils/gasFee';
import { TokenAndPaymaster } from '../utils/tokenAndPaymaster';

export class EIP4337Lib {

    public static Utils = {
        getNonce: EIP4337Lib.getNonce,
        DecodeCallData: DecodeCallData,
        fromTransaction: Converter.fromTransaction,
        suggestedGasFee: CodefiGasFees,
        tokenAndPaymaster: TokenAndPaymaster
    }

    public static Defines = {
        AddressZero: AddressZero
    }

    public static Guaridian = Guaridian;

    public static Tokens = {
        ERC20: ERC20,
        ERC721: ERC721,
        ERC1155: ERC1155,
        ETH: ETH,
    };

    public static RPC = {
        eth_sendUserOperation: RPC.eth_sendUserOperation,
        eth_supportedEntryPoints: RPC.eth_supportedEntryPoints,
        waitUserOperation: RPC.waitUserOperation,
        simulateValidation: RPC.simulateValidation,
        simulateHandleOp: RPC.simulateHandleOp,
    }


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
    private static getInitializeData(
        entryPointAddress: string,
        ownerAddress: string,
        upgradeDelay: number,
        guardianDelay: number,
        guardianAddress: string,
        tokenAndPaymaster: string
    ) {
        // function initialize(IEntryPoint anEntryPoint, address anOwner,  IERC20 token,address paymaster)
        // encodeFunctionData
        let iface = new ethers.utils.Interface(SimpleWalletContract.ABI);
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
    public static getWalletCode(walletLogicAddress: string, entryPointAddress: string, ownerAddress: string, upgradeDelay: number, guardianDelay: number, guardianAddress: string, tokenAndPaymaster: string): string {
        const initializeData = EIP4337Lib.getInitializeData(entryPointAddress, ownerAddress, upgradeDelay, guardianDelay, guardianAddress, tokenAndPaymaster);
        const factory = new ethers.ContractFactory(WalletProxyContract.ABI, WalletProxyContract.bytecode);
        const walletBytecode = factory.getDeployTransaction(walletLogicAddress, initializeData).data;
        return walletBytecode as string;
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
    public static calculateWalletAddress(
        walletLogicAddress: string,
        entryPointAddress: string,
        ownerAddress: string,
        upgradeDelay: number,
        guardianDelay: number,
        guardianAddress: string,
        tokenAndPaymaster: string,
        salt: number,
        create2Factory: string) {
        const initCodeWithArgs = EIP4337Lib.getWalletCode(walletLogicAddress, entryPointAddress, ownerAddress, upgradeDelay, guardianDelay, guardianAddress, tokenAndPaymaster);
        const initCodeHash = keccak256(initCodeWithArgs);
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
    public static activateWalletOp(
        walletLogicAddress: string,
        entryPointAddress: string,
        ownerAddress: string,
        upgradeDelay: number,
        guardianDelay: number,
        guardianAddress: string,
        tokenAndPaymaster: string,
        payMasterAddress: string,
        salt: number,
        create2Factory: string,
        maxFeePerGas: NumberLike,
        maxPriorityFeePerGas: NumberLike) {
        const initCodeWithArgs = EIP4337Lib.getWalletCode(walletLogicAddress, entryPointAddress, ownerAddress, upgradeDelay, guardianDelay, guardianAddress, tokenAndPaymaster);
        const initCodeHash = keccak256(initCodeWithArgs);
        const walletAddress = EIP4337Lib.calculateWalletAddressByCodeHash(initCodeHash, salt, create2Factory);
        let userOperation: UserOperation = new UserOperation();
        userOperation.nonce = 0;
        userOperation.sender = walletAddress;
        userOperation.paymasterAndData = payMasterAddress;
        userOperation.maxFeePerGas = maxFeePerGas;
        userOperation.maxPriorityFeePerGas = maxPriorityFeePerGas;
        userOperation.initCode = EIP4337Lib.getPackedInitCode(create2Factory, initCodeWithArgs, salt);
        userOperation.verificationGasLimit = 500000;//100000 + 3200 + 200 * userOperation.initCode.length;
        userOperation.callGasLimit = 0;
        userOperation.callData = "0x";
        return userOperation;
    }

    public static getPackedInitCode(create2Factory: string, initCode: string, salt: number) {
        const abi = { "inputs": [{ "internalType": "bytes", "name": "_initCode", "type": "bytes" }, { "internalType": "bytes32", "name": "_salt", "type": "bytes32" }], "name": "deploy", "outputs": [{ "internalType": "address payable", "name": "createdContract", "type": "address" }], "stateMutability": "nonpayable", "type": "function" };
        let iface = new ethers.utils.Interface([abi]);
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
    public static calculateWalletAddressByCode(
        initContract: IContract,
        initArgs: any[] | undefined,
        salt: number,
        create2Factory: string): string {
        const factory = new ethers.ContractFactory(initContract.ABI, initContract.bytecode);
        const initCodeWithArgs = factory.getDeployTransaction(initArgs).data as string;
        const initCodeHash = keccak256(initCodeWithArgs);
        return EIP4337Lib.calculateWalletAddressByCodeHash(initCodeHash, salt, create2Factory);

    }

    public static number2Bytes32(num: number) {
        return hexZeroPad(hexlify(num), 32);
    }

    /**
     * calculate EIP-4337 wallet address
     * @param initCodeHash the init code after keccak256
     * @param salt the salt number
     * @param create2Factory create2factory address defined in EIP-2470
     * @returns the EIP-4337 wallet address
     */
    private static calculateWalletAddressByCodeHash(
        initCodeHash: string,
        salt: number,
        create2Factory: string): string {
        return getCreate2Address(create2Factory, EIP4337Lib.number2Bytes32(salt), initCodeHash);
    }


    /**
     * get nonce number from contract wallet
     * @param walletAddress the wallet address
     * @param web3 the web3 instance
     * @param defaultBlock "earliest", "latest" and "pending"
     * @returns the next nonce number
     */
    private static async getNonce(walletAddress: string, etherProvider: ethers.providers.BaseProvider, defaultBlock = 'latest'): Promise<number> {
        try {
            const code = await etherProvider.getCode(walletAddress, defaultBlock);
            // check contract is exist
            if (code === '0x') {
                return 0;
            } else {
                const contract = new ethers.Contract(walletAddress, [{ "inputs": [], "name": "nonce", "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }], "stateMutability": "view", "type": "function" }], etherProvider);
                const nonce = await contract.nonce();
                // try parse to number
                const nextNonce = parseInt(nonce, 10);
                if (isNaN(nextNonce)) {
                    throw new Error('nonce is not a number');
                }
                return nextNonce;
            }

        } catch (error) {
            throw error;
        }
    }


}

export { UserOperation } from "../entity/userOperation";