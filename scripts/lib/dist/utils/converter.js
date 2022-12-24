"use strict";
/*
 * @Description:
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-11-07 21:08:08
 * @LastEditors: cejay
 * @LastEditTime: 2022-12-23 19:46:07
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
exports.Converter = void 0;
const userOperation_1 = require("../entity/userOperation");
const ABI_1 = require("../defines/ABI");
const ethers_1 = require("ethers");
class Converter {
    static fromTransaction(etherProvider, entryPointAddress, transcation, nonce = 0, maxFeePerGas = 0, maxPriorityFeePerGas = 0, paymasterAndData = "0x") {
        return __awaiter(this, void 0, void 0, function* () {
            const op = new userOperation_1.UserOperation();
            op.sender = transcation.from;
            //op.preVerificationGas = 150000;
            op.nonce = nonce;
            op.paymasterAndData = paymasterAndData;
            op.maxFeePerGas = maxFeePerGas;
            op.maxPriorityFeePerGas = maxPriorityFeePerGas;
            op.callGasLimit = parseInt(transcation.gas, 16);
            op.callData = new ethers_1.ethers.utils.Interface(ABI_1.execFromEntryPoint)
                .encodeFunctionData("execFromEntryPoint", [transcation.to, transcation.value, transcation.data]);
            let gasEstimated = yield op.estimateGas(entryPointAddress, etherProvider);
            if (!gasEstimated) {
                return null;
            }
            return op;
        });
    }
}
exports.Converter = Converter;
//# sourceMappingURL=converter.js.map