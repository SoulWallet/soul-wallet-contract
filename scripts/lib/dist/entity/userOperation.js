"use strict";
/*
 * @Description:
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-07-25 10:53:52
 * @LastEditors: cejay
 * @LastEditTime: 2023-01-28 09:45:54
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
exports.UserOperation = void 0;
const ethers_1 = require("ethers");
const address_1 = require("../defines/address");
const numberLike_1 = require("../defines/numberLike");
const userOp_1 = require("../utils/userOp");
/**
 * @link https://github.com/eth-infinitism/account-abstraction/blob/develop/contracts/UserOperation.sol
 */
class UserOperation {
    constructor() {
        this.sender = '';
        this.nonce = 0;
        this.initCode = '0x';
        this.callData = '0x';
        this.callGasLimit = 0;
        this.verificationGasLimit = 80000;
        this.preVerificationGas = 2100;
        this.maxFeePerGas = 0;
        this.maxPriorityFeePerGas = 0;
        this.paymasterAndData = '0x';
        this.signature = '0x';
    }
    toTuple() {
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
    toJSON() {
        return JSON.stringify({
            sender: this.sender,
            nonce: (0, numberLike_1.toHexString)(this.nonce),
            initCode: this.initCode,
            callData: this.callData,
            callGasLimit: (0, numberLike_1.toHexString)(this.callGasLimit),
            verificationGasLimit: (0, numberLike_1.toHexString)(this.verificationGasLimit),
            preVerificationGas: (0, numberLike_1.toHexString)(this.preVerificationGas),
            maxFeePerGas: (0, numberLike_1.toHexString)(this.maxFeePerGas),
            maxPriorityFeePerGas: (0, numberLike_1.toHexString)(this.maxPriorityFeePerGas),
            paymasterAndData: this.paymasterAndData === address_1.AddressZero ? '0x' : this.paymasterAndData,
            signature: this.signature
        });
    }
    static fromJSON(json) {
        const obj = JSON.parse(json);
        if (!obj || typeof obj !== 'object') {
            throw new Error('invalid json');
        }
        if (typeof obj.sender !== 'string') {
            throw new Error('invalid sender');
        }
        if (typeof obj.nonce !== 'string' && typeof obj.nonce !== 'number') {
            throw new Error('invalid nonce');
        }
        if (typeof obj.initCode !== 'string' || !obj.initCode.startsWith('0x')) {
            throw new Error('invalid initCode');
        }
        if (typeof obj.callData !== 'string' || !obj.callData.startsWith('0x')) {
            throw new Error('invalid callData');
        }
        if (typeof obj.callGasLimit !== 'string' && typeof obj.callGasLimit !== 'number') {
            throw new Error('invalid callGasLimit');
        }
        if (typeof obj.verificationGasLimit !== 'string' && typeof obj.verificationGasLimit !== 'number') {
            throw new Error('invalid verificationGasLimit');
        }
        if (typeof obj.preVerificationGas !== 'string' && typeof obj.preVerificationGas !== 'number') {
            throw new Error('invalid preVerificationGas');
        }
        if (typeof obj.maxFeePerGas !== 'string' && typeof obj.maxFeePerGas !== 'number') {
            throw new Error('invalid maxFeePerGas');
        }
        if (typeof obj.maxPriorityFeePerGas !== 'string' && typeof obj.maxPriorityFeePerGas !== 'number') {
            throw new Error('invalid maxPriorityFeePerGas');
        }
        if (typeof obj.paymasterAndData !== 'string' || !obj.paymasterAndData.startsWith('0x')) {
            throw new Error('invalid paymasterAndData');
        }
        if (typeof obj.signature !== 'string' || !obj.signature.startsWith('0x')) {
            throw new Error('invalid signature');
        }
        const userOp = new UserOperation();
        userOp.sender = obj.sender;
        userOp.nonce = (0, numberLike_1.toNumber)(obj.nonce);
        userOp.initCode = obj.initCode;
        userOp.callData = obj.callData;
        userOp.callGasLimit = obj.callGasLimit;
        userOp.verificationGasLimit = obj.verificationGasLimit;
        userOp.preVerificationGas = obj.preVerificationGas;
        userOp.maxFeePerGas = obj.maxFeePerGas;
        userOp.maxPriorityFeePerGas = obj.maxPriorityFeePerGas;
        userOp.paymasterAndData = obj.paymasterAndData;
        userOp.signature = obj.signature;
        return userOp;
    }
    /**
     * estimate the gas
     * @param entryPointAddress the entry point address
     * @param estimateGasFunc the estimate gas function
     * @returns false if failed
     */
    estimateGas(entryPointAddress, etherProvider
    // estimateGasFunc: (txInfo: ethers.utils.Deferrable<ethers.providers.TransactionRequest>) => Promise<BigNumber> //(transaction:ethers.providers.TransactionRequest):Promise<number>
    // (transaction: ethers.utils.Deferrable<ethers.providers.TransactionRequest>): Promise<ether.BigNumber>
    ) {
        return __awaiter(this, void 0, void 0, function* () {
            try {
                // //  // Single signer 385000,
                // this.verificationGasLimit = 60000;
                // if (this.initCode.length > 0) {
                //     this.verificationGasLimit += (3200 + 200 * this.initCode.length);
                // }
                const estimateGasRe = yield etherProvider.estimateGas({
                    from: entryPointAddress,
                    to: this.sender,
                    data: this.callData,
                    gasLimit: 20000000
                });
                this.callGasLimit = estimateGasRe.toNumber();
                return true;
            }
            catch (error) {
                console.log(error);
                return false;
            }
        });
    }
    /**
     * get the paymaster sign hash
     * @returns
     */
    payMasterSignHash() {
        return (0, userOp_1.payMasterSignHash)(this);
    }
    /**
     * sign the user operation
     * @param entryPoint the entry point address
     * @param chainId the chain id
     * @param privateKey the private key
     */
    sign(entryPoint, chainId, privateKey) {
        this.signature = (0, userOp_1.signUserOp)(this, entryPoint, chainId, privateKey);
    }
    /**
     * sign the user operation with personal sign
     * @param signAddress the sign address
     * @param signature the signature of the UserOpHash
     */
    signWithSignature(signAddress, signature) {
        this.signature = (0, userOp_1.signUserOpWithPersonalSign)(signAddress, signature);
    }
    /**
     * sign the user operation with guardians sign
     * @param guardianAddress guardian address
     * @param signature guardians signature
     * @param deadline deadline (block timestamp)
     * @param initCode guardian contract init code
     */
    signWithGuardiansSign(guardianAddress, signature, deadline = 0, initCode = '0x') {
        this.signature = (0, userOp_1.packGuardiansSignByInitCode)(guardianAddress, signature, deadline, initCode);
    }
    /**
     * get the UserOpHash (userOp hash)
     * @param entryPointAddress the entry point address
     * @param chainId the chain id
     * @returns hex string
     */
    getUserOpHash(entryPointAddress, chainId) {
        return (0, userOp_1.getUserOpHash)(this, entryPointAddress, chainId);
    }
    /**
     * get the UserOpHash (userOp hash) with deadline
     * @param entryPointAddress
     * @param chainId
     * @param deadline unix timestamp
     * @returns bytes32 hash
     */
    getUserOpHashWithDeadline(entryPointAddress, chainId, deadline) {
        const _hash = this.getUserOpHash(entryPointAddress, chainId);
        return ethers_1.ethers.utils.solidityKeccak256(['bytes32', 'uint64'], [_hash, deadline]);
    }
}
exports.UserOperation = UserOperation;
//# sourceMappingURL=userOperation.js.map