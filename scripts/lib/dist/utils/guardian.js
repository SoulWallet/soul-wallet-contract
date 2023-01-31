"use strict";
/*
 * @Description:
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-09-21 20:28:54
 * @LastEditors: cejay
 * @LastEditTime: 2023-01-28 10:17:34
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
exports.Guaridian = void 0;
const userOperation_1 = require("../entity/userOperation");
const soulWallet_1 = require("../contracts/soulWallet");
const ethers_1 = require("ethers");
const guardianMultiSigWallet_1 = require("../contracts/guardianMultiSigWallet");
const walletProxy_1 = require("../contracts/walletProxy");
const utils_1 = require("ethers/lib/utils");
const address_1 = require("../defines/address");
class Guaridian {
    static getInitializeData(guardians, threshold) {
        // function initialize(address[] calldata _guardians, uint16 _threshold)
        // order by guardians asc
        // For user experience, guardian cannot rely on the order of address
        guardians.sort((a, b) => {
            const aBig = ethers_1.BigNumber.from(a);
            const bBig = ethers_1.BigNumber.from(b);
            if (aBig.eq(bBig)) {
                throw new Error(`guardian address is same: ${a}`);
            }
            else if (aBig.lt(bBig)) {
                return -1;
            }
            else {
                return 1;
            }
        });
        let iface = new ethers_1.ethers.utils.Interface(guardianMultiSigWallet_1.GuardianMultiSigWallet.ABI);
        let initializeData = iface.encodeFunctionData("initialize", [guardians, threshold]);
        return initializeData;
    }
    static getGuardianCode(guardianLogicAddress, guardians, threshold) {
        const initializeData = Guaridian.getInitializeData(guardians, threshold);
        const factory = new ethers_1.ethers.ContractFactory(walletProxy_1.WalletProxyContract.ABI, walletProxy_1.WalletProxyContract.bytecode);
        const walletBytecode = factory.getDeployTransaction(guardianLogicAddress, initializeData).data;
        return walletBytecode;
    }
    static getPackedInitCode(create2Factory, initCode, salt) {
        const abi = { "inputs": [{ "internalType": "bytes", "name": "_initCode", "type": "bytes" }, { "internalType": "bytes32", "name": "_salt", "type": "bytes32" }], "name": "deploy", "outputs": [{ "internalType": "address payable", "name": "createdContract", "type": "address" }], "stateMutability": "nonpayable", "type": "function" };
        let iface = new ethers_1.ethers.utils.Interface([abi]);
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
    static calculateGuardianAndInitCode(guardianLogicAddress, guardians, threshold, salt, create2Factory) {
        // check if salt is bytes32 (length 66, starts with 0x, and is hex(0-9 a-f))
        if (/^0x[a-f0-9]{64}$/.test(salt) === false) {
            // salt to bytes32
            salt = (0, utils_1.keccak256)(utils_1.defaultAbiCoder.encode(['string'], [salt]));
        }
        const initCodeWithArgs = Guaridian.getGuardianCode(guardianLogicAddress, guardians, threshold);
        const initCodeHash = (0, utils_1.keccak256)(initCodeWithArgs);
        const address = (0, utils_1.getCreate2Address)(create2Factory, salt, initCodeHash);
        const initCode = Guaridian.getPackedInitCode(create2Factory, initCodeWithArgs, salt);
        return {
            address,
            initCode
        };
    }
    static walletContract(etherProvider, walletAddress) {
        return new ethers_1.ethers.Contract(walletAddress, soulWallet_1.SimpleWalletContract.ABI, etherProvider);
    }
    /**
     * get guardian info
     * @param etherProvider
     * @param walletAddress EIP4337 wallet address
     * @param now current timestamp ( 0: use current timestamp, >0:unix timestamp  )
     * @returns (currentGuardian, guardianDelay)
     */
    static getGuardian(etherProvider, walletAddress, now = 0) {
        return __awaiter(this, void 0, void 0, function* () {
            const walletContract = Guaridian.walletContract(etherProvider, walletAddress);
            const result = yield etherProvider.call({
                from: address_1.AddressZero,
                to: walletAddress,
                data: new ethers_1.ethers.utils.Interface(soulWallet_1.SimpleWalletContract.ABI).encodeFunctionData("guardianInfo", []),
            });
            const decoded = new ethers_1.ethers.utils.Interface(soulWallet_1.SimpleWalletContract.ABI).decodeFunctionResult("guardianInfo", result);
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
                currentGuardian: ethers_1.ethers.utils.getAddress(currentGuardian),
                nextGuardian: ethers_1.ethers.utils.getAddress(decoded[1]),
                nextGuardianActivateTime: activateTime,
                guardianDelay: parseInt(decoded[3]),
            };
        });
    }
    static _guardian(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAndData, maxFeePerGas, maxPriorityFeePerGas, callData) {
        return __awaiter(this, void 0, void 0, function* () {
            walletAddress = ethers_1.ethers.utils.getAddress(walletAddress);
            let userOperation = new userOperation_1.UserOperation();
            userOperation.nonce = nonce;
            userOperation.sender = walletAddress;
            userOperation.paymasterAndData = paymasterAndData;
            userOperation.maxFeePerGas = maxFeePerGas;
            userOperation.maxPriorityFeePerGas = maxPriorityFeePerGas;
            userOperation.callData = callData;
            let gasEstimated = yield userOperation.estimateGas(entryPointAddress, etherProvider);
            if (!gasEstimated) {
                return null;
            }
            return userOperation;
        });
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
    static setGuardian(etherProvider, walletAddress, guardian, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas) {
        return __awaiter(this, void 0, void 0, function* () {
            guardian = ethers_1.ethers.utils.getAddress(guardian);
            const iface = new ethers_1.ethers.utils.Interface(soulWallet_1.SimpleWalletContract.ABI);
            const calldata = iface.encodeFunctionData("setGuardian", [guardian]);
            return yield this._guardian(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, calldata);
        });
    }
    static transferOwner(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, newOwner) {
        return __awaiter(this, void 0, void 0, function* () {
            newOwner = ethers_1.ethers.utils.getAddress(newOwner);
            const iface = new ethers_1.ethers.utils.Interface(soulWallet_1.SimpleWalletContract.ABI);
            const calldata = iface.encodeFunctionData("transferOwner", [newOwner]);
            const op = yield this._guardian(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, calldata);
            if (op)
                op.verificationGasLimit = 600000;
            return op;
        });
    }
    static guardianSign(signature) {
        if (signature.length === 0) {
            throw new Error("signature is empty");
        }
        signature.sort((a, b) => {
            return ethers_1.BigNumber.from(a.address).lt(ethers_1.BigNumber.from(b.address)) ? -1 : 1;
        });
        let guardianSignature = [];
        let contractWalletCount = 0;
        for (let i = 0; i < signature.length; i++) {
            const signatureItem = signature[i];
            signatureItem.address = signatureItem.address.toLocaleLowerCase();
            signatureItem.signature = signatureItem.signature.toLocaleLowerCase();
            if (signatureItem.signature.startsWith('0x')) {
                signatureItem.signature = signatureItem.signature.slice(2);
            }
            if (signatureItem.contract) {
                const r = `000000000000000000000000${signatureItem.address.slice(2)}`;
                const s = ethers_1.ethers.utils
                    .hexZeroPad(ethers_1.ethers.utils.hexlify((65 * signature.length) + ((contractWalletCount++) * (32 + 65))), 32)
                    .slice(2);
                const v = `00`;
                const _signature = {
                    signer: signatureItem.address,
                    rsvSig: `${r}${s}${v}`,
                    offsetSig: `0000000000000000000000000000000000000000000000000000000000000041${signatureItem.signature}`,
                };
                guardianSignature.push(_signature);
            }
            else {
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
exports.Guaridian = Guaridian;
//# sourceMappingURL=Guardian.js.map