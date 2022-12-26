/*
 * @Description: 
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-07-25 10:53:52
 * @LastEditors: cejay
 * @LastEditTime: 2022-12-26 22:31:57
 */

import { ethers, BigNumber } from "ethers";
import { Deferrable } from "ethers/lib/utils";
import { NumberLike, toDecString } from "../defines/numberLike";
import { guardianSignature } from "../utils/guardian";
import { signUserOp, payMasterSignHash, getUserOpHash, signUserOpWithPersonalSign, packGuardiansSignByInitCode } from '../utils/userOp';
import { TransactionInfo } from './transactionInfo';

/**
 * @link https://github.com/eth-infinitism/account-abstraction/blob/develop/contracts/UserOperation.sol    
 */

class UserOperation {

    public sender: string = '';
    public nonce: number = 0;
    public initCode: string = '0x';
    public callData: string = '0x';
    public callGasLimit: NumberLike = 0;
    public verificationGasLimit: NumberLike = 60000;
    public preVerificationGas: NumberLike = 2100;
    public maxFeePerGas: NumberLike = 0;
    public maxPriorityFeePerGas: NumberLike = 0;
    public paymasterAndData: string = '0x';
    public signature: string = '0x';

    public toTuple(): string {
        /* 
        address sender;
        uint256 nonce;
        bytes initCode;
        bytes callData;
        uint callGas;
        uint verificationGas;
        uint preVerificationGas;
        uint maxFeePerGas;
        uint maxPriorityFeePerGas;
        address paymaster;
        bytes paymasterData;
        bytes signature;
        */
        return `["${this.sender.toLocaleLowerCase()}","${this.nonce}","${this.initCode}","${this.callData}","${this.callGasLimit}","${this.verificationGasLimit}","${this.preVerificationGas}","${this.maxFeePerGas}","${this.maxPriorityFeePerGas}","${this.paymasterAndData}","${this.signature}"]`;
    }

    public toJSON(): string {
        return JSON.stringify({
            sender: this.sender,
            nonce: this.nonce,
            initCode: this.initCode,
            callData: this.callData,
            callGasLimit: toDecString(this.callGasLimit),
            verificationGasLimit: toDecString(this.verificationGasLimit),
            preVerificationGas: toDecString(this.preVerificationGas),
            maxFeePerGas: toDecString(this.maxFeePerGas),
            maxPriorityFeePerGas: toDecString(this.maxPriorityFeePerGas),
            paymasterAndData: this.paymasterAndData,
            signature: this.signature
        });
    }

    /**
     * estimate the gas
     * @param entryPointAddress the entry point address
     * @param estimateGasFunc the estimate gas function
     * @returns false if failed
     */
    public async estimateGas(
        entryPointAddress: string,
        etherProvider: ethers.providers.BaseProvider
        // estimateGasFunc: (txInfo: ethers.utils.Deferrable<ethers.providers.TransactionRequest>) => Promise<BigNumber> //(transaction:ethers.providers.TransactionRequest):Promise<number>
        // (transaction: ethers.utils.Deferrable<ethers.providers.TransactionRequest>): Promise<ether.BigNumber>
    ) {
        try {
            // //  // Single signer 385000,
            // this.verificationGasLimit = 60000;
            // if (this.initCode.length > 0) {
            //     this.verificationGasLimit += (3200 + 200 * this.initCode.length);
            // }
            const estimateGasRe = await etherProvider.estimateGas({
                from: entryPointAddress,
                to: this.sender,
                data: this.callData
            });

            this.callGasLimit = estimateGasRe.toNumber();
            return true;
        } catch (error) {
            console.log(error);
            return false;
        }

    }

    /**
     * get the paymaster sign hash
     * @returns 
     */
    public payMasterSignHash(): string {
        return payMasterSignHash(this);
    }

    /**
     * sign the user operation
     * @param entryPoint the entry point address
     * @param chainId the chain id
     * @param privateKey the private key
     */
    public sign(
        entryPoint: string,
        chainId: number,
        privateKey: string): void {
        this.signature = signUserOp(this, entryPoint, chainId, privateKey);
    }


    /**
     * sign the user operation with personal sign
     * @param signAddress the sign address
     * @param signature the signature of the UserOpHash
     */
    public signWithSignature(signAddress: string, signature: string) {
        this.signature = signUserOpWithPersonalSign(signAddress, signature);
    }

    /**
     * sign the user operation with guardians sign
     * @param guardianAddress guardian address
     * @param signature guardians signature
     * @param deadline deadline (block timestamp)
     * @param initCode guardian contract init code
     */
    public signWithGuardiansSign(guardianAddress: string, signature: guardianSignature[],deadline = 0, initCode = '0x') {
        this.signature = packGuardiansSignByInitCode(guardianAddress, signature, deadline,initCode);
    }


    /**
     * get the UserOpHash (userOp hash)
     * @param entryPointAddress the entry point address
     * @param chainId the chain id
     * @returns hex string
     */
    public getUserOpHash(entryPointAddress: string, chainId: number): string {
        return getUserOpHash(this, entryPointAddress, chainId);
    }

}



export { UserOperation };