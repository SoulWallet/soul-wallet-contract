import { ethers } from "ethers";
import { NumberLike } from "../defines/numberLike";
import { guardianSignature } from "../utils/Guardian";
/**
 * @link https://github.com/eth-infinitism/account-abstraction/blob/develop/contracts/UserOperation.sol
 */
declare class UserOperation {
    sender: string;
    nonce: number;
    initCode: string;
    callData: string;
    callGasLimit: NumberLike;
    verificationGasLimit: NumberLike;
    preVerificationGas: NumberLike;
    maxFeePerGas: NumberLike;
    maxPriorityFeePerGas: NumberLike;
    paymasterAndData: string;
    signature: string;
    toTuple(): string;
    toJSON(): string;
    static fromJSON(json: string): UserOperation;
    /**
     * estimate the gas
     * @param entryPointAddress the entry point address
     * @param estimateGasFunc the estimate gas function
     * @returns false if failed
     */
    estimateGas(entryPointAddress: string, etherProvider: ethers.providers.BaseProvider): Promise<boolean>;
    /**
     * get the paymaster sign hash
     * @returns
     */
    payMasterSignHash(): string;
    /**
     * sign the user operation
     * @param entryPoint the entry point address
     * @param chainId the chain id
     * @param privateKey the private key
     */
    sign(entryPoint: string, chainId: number, privateKey: string): void;
    /**
     * sign the user operation with personal sign
     * @param signAddress the sign address
     * @param signature the signature of the UserOpHash
     */
    signWithSignature(signAddress: string, signature: string): void;
    /**
     * sign the user operation with guardians sign
     * @param guardianAddress guardian address
     * @param signature guardians signature
     * @param deadline deadline (block timestamp)
     * @param initCode guardian contract init code
     */
    signWithGuardiansSign(guardianAddress: string, signature: guardianSignature[], deadline?: number, initCode?: string): void;
    /**
     * get the UserOpHash (userOp hash)
     * @param entryPointAddress the entry point address
     * @param chainId the chain id
     * @returns hex string
     */
    getUserOpHash(entryPointAddress: string, chainId: number): string;
    /**
     * get the UserOpHash (userOp hash) with deadline
     * @param entryPointAddress
     * @param chainId
     * @param deadline unix timestamp
     * @returns bytes32 hash
     */
    getUserOpHashWithDeadline(entryPointAddress: string, chainId: number, deadline: number): string;
}
export { UserOperation };
