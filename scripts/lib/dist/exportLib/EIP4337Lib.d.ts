import { UserOperation } from "../entity/userOperation";
import { IContract } from "../contracts/icontract";
import { DecodeCallData } from '../utils/decodeCallData';
import { Guaridian } from "../utils/Guardian";
import { ERC1155, ERC20, ERC721, ETH } from "../utils/Token";
import { RPC } from '../utils/rpc';
import { Converter } from "../utils/converter";
import { NumberLike } from "../defines/numberLike";
import { CodefiGasFees } from '../utils/gasFee';
import { TokenAndPaymaster } from '../utils/tokenAndPaymaster';
export declare class EIP4337Lib {
    static Utils: {
        getNonce: typeof EIP4337Lib.getNonce;
        DecodeCallData: typeof DecodeCallData;
        fromTransaction: typeof Converter.fromTransaction;
        suggestedGasFee: typeof CodefiGasFees;
        tokenAndPaymaster: typeof TokenAndPaymaster;
    };
    static Defines: {
        AddressZero: string;
    };
    static Guaridian: typeof Guaridian;
    static Tokens: {
        ERC20: typeof ERC20;
        ERC721: typeof ERC721;
        ERC1155: typeof ERC1155;
        ETH: typeof ETH;
    };
    static RPC: {
        eth_sendUserOperation: typeof RPC.eth_sendUserOperation;
        eth_supportedEntryPoints: typeof RPC.eth_supportedEntryPoints;
        waitUserOperation: typeof RPC.waitUserOperation;
        simulateValidation: typeof RPC.simulateValidation;
        simulateHandleOp: typeof RPC.simulateHandleOp;
    };
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
    private static getInitializeData;
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
    static getWalletCode(walletLogicAddress: string, entryPointAddress: string, ownerAddress: string, upgradeDelay: number, guardianDelay: number, guardianAddress: string, tokenAndPaymaster: string): string;
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
    static calculateWalletAddress(walletLogicAddress: string, entryPointAddress: string, ownerAddress: string, upgradeDelay: number, guardianDelay: number, guardianAddress: string, tokenAndPaymaster: string, salt: number, create2Factory: string): string;
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
    static activateWalletOp(walletLogicAddress: string, entryPointAddress: string, ownerAddress: string, upgradeDelay: number, guardianDelay: number, guardianAddress: string, tokenAndPaymaster: string, payMasterAddress: string, salt: number, create2Factory: string, maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike): UserOperation;
    static getPackedInitCode(create2Factory: string, initCode: string, salt: number): string;
    /**
     * calculate EIP-4337 wallet address
     * @param initContract the init Contract
     * @param initArgs the init args
     * @param salt the salt number
     * @param create2Factory create2factory address defined in EIP-2470
     * @returns
     */
    static calculateWalletAddressByCode(initContract: IContract, initArgs: any[] | undefined, salt: number, create2Factory: string): string;
    static number2Bytes32(num: number): string;
    /**
     * calculate EIP-4337 wallet address
     * @param initCodeHash the init code after keccak256
     * @param salt the salt number
     * @param create2Factory create2factory address defined in EIP-2470
     * @returns the EIP-4337 wallet address
     */
    private static calculateWalletAddressByCodeHash;
    /**
     * get nonce number from contract wallet
     * @param walletAddress the wallet address
     * @param web3 the web3 instance
     * @param defaultBlock "earliest", "latest" and "pending"
     * @returns the next nonce number
     */
    private static getNonce;
}
export { UserOperation } from "../entity/userOperation";
