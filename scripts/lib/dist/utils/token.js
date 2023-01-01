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
Object.defineProperty(exports, "__esModule", { value: true });
exports.ETH = exports.ERC1155 = exports.ERC721 = exports.ERC20 = exports.Token = void 0;
/*
 * @Description:
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-09-21 21:45:49
 * @LastEditors: cejay
 * @LastEditTime: 2022-12-19 09:53:28
 */
const userOperation_1 = require("../entity/userOperation");
const ABI_1 = require("../defines/ABI");
const ethers_1 = require("ethers");
class Token {
    static createOp(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAndData, maxFeePerGas, maxPriorityFeePerGas, callContract, encodeABI, value = '0') {
        return __awaiter(this, void 0, void 0, function* () {
            walletAddress = ethers_1.ethers.utils.getAddress(walletAddress);
            let userOperation = new userOperation_1.UserOperation();
            userOperation.nonce = nonce;
            userOperation.sender = walletAddress;
            userOperation.paymasterAndData = paymasterAndData;
            userOperation.maxFeePerGas = maxFeePerGas;
            userOperation.maxPriorityFeePerGas = maxPriorityFeePerGas;
            userOperation.callData = new ethers_1.ethers.utils.Interface(ABI_1.execFromEntryPoint)
                .encodeFunctionData("execFromEntryPoint", [callContract, value, encodeABI]);
            let gasEstimated = yield userOperation.estimateGas(entryPointAddress, etherProvider);
            if (!gasEstimated) {
                return null;
            }
            return userOperation;
        });
    }
}
exports.Token = Token;
class ERC20 {
    static getContract(etherProvider, contractAddress) {
        return new ethers_1.ethers.Contract(contractAddress, ABI_1.ERC20, etherProvider);
    }
    static approve(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, _spender, _value) {
        return __awaiter(this, void 0, void 0, function* () {
            let encodeABI = new ethers_1.ethers.utils.Interface(ABI_1.ERC20).encodeFunctionData("approve", [_spender, _value]);
            return yield Token.createOp(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, encodeABI);
        });
    }
    static transferFrom(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, _from, _to, _value) {
        return __awaiter(this, void 0, void 0, function* () {
            let encodeABI = new ethers_1.ethers.utils.Interface(ABI_1.ERC20).encodeFunctionData("transferFrom", [_from, _to, _value]);
            return yield Token.createOp(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, encodeABI);
        });
    }
    static transfer(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, _to, _value) {
        return __awaiter(this, void 0, void 0, function* () {
            let encodeABI = new ethers_1.ethers.utils.Interface(ABI_1.ERC20).encodeFunctionData("transfer", [_to, _value]);
            return yield Token.createOp(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, encodeABI);
        });
    }
}
exports.ERC20 = ERC20;
class ERC721 {
    static getContract(etherProvider, contractAddress) {
        return new ethers_1.ethers.Contract(contractAddress, ABI_1.ERC721, etherProvider);
    }
    static approve(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, _spender, _tokenId) {
        return __awaiter(this, void 0, void 0, function* () {
            let encodeABI = new ethers_1.ethers.utils.Interface(ABI_1.ERC721).encodeFunctionData("approve", [_spender, _tokenId]);
            return yield Token.createOp(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, encodeABI);
        });
    }
    static transferFrom(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, _from, _to, _tokenId) {
        return __awaiter(this, void 0, void 0, function* () {
            let encodeABI = new ethers_1.ethers.utils.Interface(ABI_1.ERC721).encodeFunctionData("transferFrom", [_from, _to, _tokenId]);
            return yield Token.createOp(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, encodeABI);
        });
    }
    static transfer(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, _to, _tokenId) {
        return __awaiter(this, void 0, void 0, function* () {
            let encodeABI = new ethers_1.ethers.utils.Interface(ABI_1.ERC721).encodeFunctionData("transfer", [_to, _tokenId]);
            return yield Token.createOp(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, encodeABI);
        });
    }
    static safeTransferFrom(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, _from, _to, _tokenId) {
        return __awaiter(this, void 0, void 0, function* () {
            let encodeABI = new ethers_1.ethers.utils.Interface(ABI_1.ERC721).encodeFunctionData("safeTransferFrom", [_from, _to, _tokenId]);
            return yield Token.createOp(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, encodeABI);
        });
    }
    static setApprovalForAll(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, _operator, _approved) {
        return __awaiter(this, void 0, void 0, function* () {
            let encodeABI = new ethers_1.ethers.utils.Interface(ABI_1.ERC721).encodeFunctionData("setApprovalForAll", [_operator, _approved]);
            return yield Token.createOp(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, encodeABI);
        });
    }
}
exports.ERC721 = ERC721;
class ERC1155 {
    static getContract(etherProvider, contractAddress) {
        return new ethers_1.ethers.Contract(contractAddress, ABI_1.ERC1155, etherProvider);
    }
    static safeTransferFrom(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, _from, _to, _id, _value, _data) {
        return __awaiter(this, void 0, void 0, function* () {
            let encodeABI = new ethers_1.ethers.utils.Interface(ABI_1.ERC1155).encodeFunctionData("safeTransferFrom", [_from, _to, _id, _value, _data]);
            return yield Token.createOp(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, encodeABI);
        });
    }
    static safeBatchTransferFrom(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, _from, _to, _ids, _values, _data) {
        return __awaiter(this, void 0, void 0, function* () {
            let encodeABI = new ethers_1.ethers.utils.Interface(ABI_1.ERC1155).encodeFunctionData("safeBatchTransferFrom", [_from, _to, _ids, _values, _data]);
            return yield Token.createOp(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, encodeABI);
        });
    }
    static setApprovalForAll(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, _operator, _approved) {
        return __awaiter(this, void 0, void 0, function* () {
            let encodeABI = new ethers_1.ethers.utils.Interface(ABI_1.ERC1155).encodeFunctionData("setApprovalForAll", [_operator, _approved]);
            return yield Token.createOp(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, encodeABI);
        });
    }
}
exports.ERC1155 = ERC1155;
class ETH {
    static transfer(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, to, value) {
        return __awaiter(this, void 0, void 0, function* () {
            return yield Token.createOp(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, to, '0x', value);
        });
    }
}
exports.ETH = ETH;
//# sourceMappingURL=Token.js.map