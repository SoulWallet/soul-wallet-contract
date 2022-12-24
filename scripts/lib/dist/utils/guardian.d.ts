import { UserOperation } from "../entity/userOperation";
import { ethers } from "ethers";
import { NumberLike } from "../defines/numberLike";
export declare class Guaridian {
    private static getInitializeData;
    private static getGuardianCode;
    private static getPackedInitCode;
    /**
     * calculate Guardian address and deploy code (initCode)
     * @param guardianLogicAddress guardian logic contract address
     * @param guardians guardian addresses
     * @param threshold threshold
     * @param salt salt
     * @param create2Factory create2 factory address
     * @returns
     */
    static calculateGuardianAndInitCode(guardianLogicAddress: string, guardians: string[], threshold: number, salt: string, create2Factory: string): {
        address: string;
        initCode: string;
    };
    private static walletContract;
    /**
     * get guardian info
     * @param etherProvider
     * @param walletAddress EIP4337 wallet address
     * @param now current timestamp ( 0: use current timestamp, >0:unix timestamp  )
     * @returns (currentGuardian, guardianDelay)
     */
    static getGuardian(etherProvider: ethers.providers.BaseProvider, walletAddress: string, now?: number): Promise<{
        currentGuardian: string;
        nextGuardian: string;
        nextGuardianActivateTime: any;
        guardianDelay: number;
    } | null>;
    private static _guardian;
    /**
     * set guardian
     * @param etherProvider
     * @param walletAddress EIP4337 wallet address
     * @param guardian new guardian address
     * @param nonce
     * @param entryPointAddress
     * @param paymasterAddress
     * @param maxFeePerGas
     * @param maxPriorityFeePerGas
     * @returns userOperation
     */
    static setGuardian(etherProvider: ethers.providers.BaseProvider, walletAddress: string, guardian: string, nonce: number, entryPointAddress: string, paymasterAddress: string, maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike): Promise<UserOperation | null>;
    static transferOwner(etherProvider: ethers.providers.BaseProvider, walletAddress: string, nonce: number, entryPointAddress: string, paymasterAddress: string, maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike, newOwner: string): Promise<UserOperation | null>;
    static guardianSign(signature: guardianSignature[]): string;
}
export interface guardianSignature {
    contract: boolean;
    address: string;
    signature: string;
}
