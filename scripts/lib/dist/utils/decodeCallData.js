"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.DecodeCallData = void 0;
/*
 * @Description:
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-09-02 22:38:58
 * @LastEditors: cejay
 * @LastEditTime: 2022-12-09 15:35:00
 */
const axios_1 = __importDefault(require("axios"));
const ethers_1 = require("ethers");
class DecodeCallData {
    constructor() {
        this.bytes4Methods = new Map();
        this._saveToStorage = null;
        this._readFromStorage = null;
        /*
     0xa9059cbb	transfer(address,uint256)
     0x095ea7b3	approve(address,uint256)
     0x23b872dd	transferFrom(address,address,uint256)
     0xb88d4fde	safeTransferFrom(address,address,uint256,bytes)
     0x42842e0e	safeTransferFrom(address,address,uint256)
     0xa22cb465	setApprovalForAll(address,bool)
     0xf242432a	safeTransferFrom(address,address,uint256,uint256,bytes)
     0x2eb2c2d6	safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)
             */
        this.bytes4Methods.set('0xa9059cbb', {
            functionName: 'transfer',
            functionSignature: 'transfer(address,uint256)',
            typesArray: ['address', 'uint256']
        });
        this.bytes4Methods.set('0x095ea7b3', {
            functionName: 'approve',
            functionSignature: 'approve(address,uint256)',
            typesArray: ['address', 'uint256']
        });
        this.bytes4Methods.set('0x23b872dd', {
            functionName: 'transferFrom',
            functionSignature: 'transferFrom(address,address,uint256)',
            typesArray: ['address', 'address', 'uint256']
        });
        this.bytes4Methods.set('0xb88d4fde', {
            functionName: 'safeTransferFrom',
            functionSignature: 'safeTransferFrom(address,address,uint256,bytes)',
            typesArray: ['address', 'address', 'uint256', 'bytes']
        });
        this.bytes4Methods.set('0x42842e0e', {
            functionName: 'safeTransferFrom',
            functionSignature: 'safeTransferFrom(address,address,uint256)',
            typesArray: ['address', 'address', 'uint256']
        });
        this.bytes4Methods.set('0xa22cb465', {
            functionName: 'setApprovalForAll',
            functionSignature: 'setApprovalForAll(address,bool)',
            typesArray: ['address', 'bool']
        });
        this.bytes4Methods.set('0xf242432a', {
            functionName: 'safeTransferFrom',
            functionSignature: 'safeTransferFrom(address,address,uint256,uint256,bytes)',
            typesArray: ['address', 'address', 'uint256', 'uint256', 'bytes']
        });
        this.bytes4Methods.set('0x2eb2c2d6', {
            functionName: 'safeBatchTransferFrom',
            functionSignature: 'safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)',
            typesArray: ['address', 'address', 'uint256[]', 'uint256[]', 'bytes']
        });
        this.bytes4Methods.set('0x80c5c7d0', {
            functionName: 'execFromEntryPoint',
            functionSignature: 'execFromEntryPoint(address,uint256,bytes)',
            typesArray: ['address', 'uint256', 'bytes']
        });
        this.bytes4Methods.set('0xe6268114', {
            functionName: 'deleteGuardianRequest',
            functionSignature: 'deleteGuardianRequest(address)',
            typesArray: ['address']
        });
        this.bytes4Methods.set('0x79f2d7c3', {
            functionName: 'grantGuardianRequest',
            functionSignature: 'grantGuardianRequest(address)',
            typesArray: ['address']
        });
        this.bytes4Methods.set('0xaaf9bbd6', {
            functionName: 'revokeGuardianRequest',
            functionSignature: 'revokeGuardianRequest(address)',
            typesArray: ['address']
        });
        this.bytes4Methods.set('0x4fb2e45d', {
            functionName: 'transferOwner',
            functionSignature: 'transferOwner(address)',
            typesArray: ['address']
        });
    }
    static new() {
        if (!DecodeCallData.instance) {
            DecodeCallData.instance = new DecodeCallData();
        }
        return DecodeCallData.instance;
    }
    /**
     * set saveToStorage function & readFromStorage function
     * @param saveToStorage async function
     * @param readFromStorage async function
     */
    setStorage(saveToStorage, readFromStorage) {
        this._saveToStorage = saveToStorage;
        this._readFromStorage = readFromStorage;
    }
    saveToStorage(key, value) {
        return __awaiter(this, void 0, void 0, function* () {
            if (this._saveToStorage) {
                yield this._saveToStorage(key, value);
            }
        });
    }
    readFromStorage(key) {
        return __awaiter(this, void 0, void 0, function* () {
            if (this._readFromStorage) {
                return yield this._readFromStorage(key);
            }
            return null;
        });
    }
    read4BytesMethod(bytes4) {
        return __awaiter(this, void 0, void 0, function* () {
            try {
                if (bytes4.length != 10) {
                    return null;
                }
                const method = yield this.readFromStorage(bytes4);
                if (method) {
                    return method;
                }
                const url = `https://www.4byte.directory/api/v1/signatures/?hex_signature=${bytes4}`;
                const response = yield axios_1.default.get(url);
                if (response && response.data && response.data.count &&
                    response.data.results && typeof (response.data.count) === 'number' &&
                    typeof (response.data.results) === 'object' && response.data.results.length > 0 &&
                    typeof (response.data.results[0].text_signature) === 'string') {
                    //watch_tg_invmru_10b052bb(bool,address,bool)
                    const text_signature = response.data.results[0].text_signature;
                    yield this.saveToStorage(bytes4, text_signature);
                    return text_signature;
                }
            }
            catch (error) {
                console.log(error);
            }
            return null;
        });
    }
    /**
     * decode call data
     * @param callData call data
     * @returns
     */
    decode(callData) {
        return __awaiter(this, void 0, void 0, function* () {
            if (!callData || callData.length < 10) {
                return null;
            }
            callData = callData.toLowerCase();
            const bytes4 = callData.slice(0, 10);
            const method = this.bytes4Methods.get(bytes4);
            if (method) {
                const typesArray = method.typesArray;
                //const params = this.web3.eth.abi.decodeParameters(typesArray, callData.slice(10));
                const params = ethers_1.ethers.utils.defaultAbiCoder.decode(typesArray, '0x' + callData.slice(10));
                //  functionSignature: 'execFromEntryPoint(address,uint256,bytes)',
                if (method.functionSignature === 'execFromEntryPoint(address,uint256,bytes)') {
                    const address = params[0];
                    const uint256 = params[1];
                    const bytes = params[2];
                    return this.decode(bytes);
                }
                else {
                    return {
                        functionName: method.functionName,
                        functionSignature: method.functionSignature,
                        params: params
                    };
                }
            }
            const methodSignature = yield this.read4BytesMethod(bytes4);
            if (!methodSignature) {
                return null;
            }
            else {
                const functionName = methodSignature.split('(')[0];
                return {
                    functionName: functionName,
                    functionSignature: methodSignature,
                    params: null
                };
            }
        });
    }
}
exports.DecodeCallData = DecodeCallData;
//# sourceMappingURL=decodeCallData.js.map