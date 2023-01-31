/*
 * @Description: 
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-09-21 20:28:54
 * @LastEditors: cejay
 * @LastEditTime: 2023-01-28 10:17:34
 */

import { UserOperation } from "../entity/userOperation";
import { SimpleWalletContract } from "../contracts/soulWallet";
import { BigNumber, ethers } from "ethers";
import { GuardianMultiSigWallet } from "../contracts/guardianMultiSigWallet";
import { WalletProxyContract } from "../contracts/walletProxy";
import { defaultAbiCoder, getCreate2Address, keccak256 } from "ethers/lib/utils";
import { AddressZero } from "../defines/address";
import { NumberLike } from "../defines/numberLike";


export class Guaridian {

    private static getInitializeData(guardians: string[], threshold: number) {
        // function initialize(address[] calldata _guardians, uint16 _threshold)
        // order by guardians asc
        // For user experience, guardian cannot rely on the order of address
        guardians.sort((a, b) => {
            const aBig = BigNumber.from(a);
            const bBig = BigNumber.from(b);
            if (aBig.eq(bBig)) {
                throw new Error(`guardian address is same: ${a}`);
            } else if (aBig.lt(bBig)) {
                return -1;
            } else {
                return 1;
            }
        });

        let iface = new ethers.utils.Interface(GuardianMultiSigWallet.ABI);
        let initializeData = iface.encodeFunctionData("initialize", [guardians, threshold]);
        return initializeData;
    }

    private static getGuardianCode(guardianLogicAddress: string, guardians: string[], threshold: number): string {
        const initializeData = Guaridian.getInitializeData(guardians, threshold);
        const factory = new ethers.ContractFactory(WalletProxyContract.ABI, WalletProxyContract.bytecode);
        const walletBytecode = factory.getDeployTransaction(guardianLogicAddress, initializeData).data;
        return walletBytecode as string;
    }

    private static getPackedInitCode(create2Factory: string, initCode: string, salt: string) {
        const abi = { "inputs": [{ "internalType": "bytes", "name": "_initCode", "type": "bytes" }, { "internalType": "bytes32", "name": "_salt", "type": "bytes32" }], "name": "deploy", "outputs": [{ "internalType": "address payable", "name": "createdContract", "type": "address" }], "stateMutability": "nonpayable", "type": "function" };
        let iface = new ethers.utils.Interface([abi]);
        let packedInitCode = iface.encodeFunctionData("deploy", [initCode, salt]).substring(2);
        return create2Factory.toLowerCase() + packedInitCode;
    }

    /**
     * calculate Guardian address and deploy code (initCode)
     * @param guardianLogicAddress guardian logic contract address
     * @param guardians guardian addresses
     * @param threshold threshold
     * @param salt salt
     * @param create2Factory create2 factory address
     * @returns 
     */
    public static calculateGuardianAndInitCode(guardianLogicAddress: string, guardians: string[], threshold: number, salt: string, create2Factory: string) {
        // check if salt is bytes32 (length 66, starts with 0x, and is hex(0-9 a-f))
        if (/^0x[a-f0-9]{64}$/.test(salt) === false) {
            // salt to bytes32
            salt = keccak256(defaultAbiCoder.encode(['string'], [salt]));
        }
        const initCodeWithArgs = Guaridian.getGuardianCode(guardianLogicAddress, guardians, threshold);
        const initCodeHash = keccak256(initCodeWithArgs);
        const address = getCreate2Address(create2Factory, salt, initCodeHash);
        const initCode = Guaridian.getPackedInitCode(create2Factory, initCodeWithArgs, salt);
        return {
            address,
            initCode
        };
    }

    private static walletContract(etherProvider: ethers.providers.BaseProvider, walletAddress: string) {
        return new ethers.Contract(walletAddress, SimpleWalletContract.ABI, etherProvider);
    }


    /**
     * get guardian info
     * @param etherProvider 
     * @param walletAddress EIP4337 wallet address
     * @param now current timestamp ( 0: use current timestamp, >0:unix timestamp  )
     * @returns (currentGuardian, guardianDelay)
     */
    public static async getGuardian(etherProvider: ethers.providers.BaseProvider, walletAddress: string, now: number = 0) {
        const walletContract = Guaridian.walletContract(etherProvider, walletAddress);

        const result = await etherProvider.call({
            from: AddressZero,
            to: walletAddress,
            data: new ethers.utils.Interface(SimpleWalletContract.ABI).encodeFunctionData("guardianInfo", []),
        });
        const decoded = new ethers.utils.Interface(SimpleWalletContract.ABI).decodeFunctionResult("guardianInfo", result);
        /* 
        
0:'0x0000000000000000000000000000000000000000'
1:'0x0000000000000000000000000000000000000000'
2:BigNumber {_hex: '0x00', _isBigNumber: true}
3:10
        */
        if (!Array.isArray(decoded) || decoded.length != 4) {
            return null;
        }
        const activateTime = decoded[2].toNumber();
        let currentGuardian = decoded[0];
        const tsNow = now > 0 ? now : Math.round(new Date().getTime() / 1000);
        if (activateTime > 0 && activateTime <= tsNow) {
            currentGuardian = decoded[1];
        }
        return {
            currentGuardian: ethers.utils.getAddress(currentGuardian),
            nextGuardian: ethers.utils.getAddress(decoded[1]),
            nextGuardianActivateTime: activateTime,
            guardianDelay: parseInt(decoded[3]),
        }
    }


    private static async _guardian(etherProvider: ethers.providers.BaseProvider, walletAddress: string, nonce: number,
        entryPointAddress: string, paymasterAndData: string,
        maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike, callData: string) {

        walletAddress = ethers.utils.getAddress(walletAddress);
        let userOperation: UserOperation = new UserOperation();
        userOperation.nonce = nonce;
        userOperation.sender = walletAddress;
        userOperation.paymasterAndData = paymasterAndData;
        userOperation.maxFeePerGas = maxFeePerGas;
        userOperation.maxPriorityFeePerGas = maxPriorityFeePerGas;
        userOperation.callData = callData;
        let gasEstimated = await userOperation.estimateGas(entryPointAddress, etherProvider);
        if (!gasEstimated) {
            return null;
        }

        return userOperation;
    }
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
    public static async setGuardian(etherProvider: ethers.providers.BaseProvider, walletAddress: string, guardian: string,
        nonce: number, entryPointAddress: string, paymasterAddress: string, maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike) {
        guardian = ethers.utils.getAddress(guardian);

        const iface = new ethers.utils.Interface(SimpleWalletContract.ABI);
        const calldata = iface.encodeFunctionData("setGuardian", [guardian]);

        return await this._guardian(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress,
            maxFeePerGas, maxPriorityFeePerGas, calldata);
    }



    public static async transferOwner(etherProvider: ethers.providers.BaseProvider, walletAddress: string,
        nonce: number, entryPointAddress: string, paymasterAddress: string,
        maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike, newOwner: string) {
        newOwner = ethers.utils.getAddress(newOwner);

        const iface = new ethers.utils.Interface(SimpleWalletContract.ABI);
        const calldata = iface.encodeFunctionData("transferOwner", [newOwner]);

        const op = await this._guardian(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress,
            maxFeePerGas, maxPriorityFeePerGas, calldata);

        if (op) op.verificationGasLimit = 600000;

        return op;
    }

    public static guardianSign(
        signature: guardianSignature[]
    ): string {
        if (signature.length === 0) {
            throw new Error("signature is empty");
        }
        signature.sort((a, b) => {
            return BigNumber.from(a.address).lt(BigNumber.from(b.address)) ? -1 : 1;
        });
        let guardianSignature = [];
        let contractWalletCount = 0;
        for (let i = 0; i < signature.length; i++) {
            const signatureItem = signature[i];
            signatureItem.address = signatureItem.address.toLocaleLowerCase();
            signatureItem.signature = signatureItem.signature.toLocaleLowerCase();
            if (signatureItem.signature.startsWith('0x')) {
                signatureItem.signature = signatureItem.signature.slice(2)
            }
            if (signatureItem.contract) {
                const r = `000000000000000000000000${signatureItem.address.slice(2)}`;
                const s = ethers.utils
                    .hexZeroPad(
                        ethers.utils.hexlify(
                            (65 * signature.length) + ((contractWalletCount++) * (32 + 65))),
                        32)
                    .slice(2);
                const v = `00`;
                const _signature = {
                    signer: signatureItem.address,
                    rsvSig: `${r}${s}${v}`,
                    offsetSig: `0000000000000000000000000000000000000000000000000000000000000041${signatureItem.signature}`,
                };
                guardianSignature.push(_signature);
            } else {
                let _signature = {
                    signer: signatureItem.address,
                    rsvSig: signatureItem.signature,
                    offsetSig: ''
                };
                guardianSignature.push(_signature);
            }
        }
        let signatureBytes = "0x";
        for (const sig of guardianSignature) {
            signatureBytes += sig.rsvSig;
        }
        for (const sig of guardianSignature) {
            signatureBytes += sig.offsetSig;
        }
        return signatureBytes;
    }

}

export interface guardianSignature {
    contract: boolean;
    address: string;
    signature: string;
}

