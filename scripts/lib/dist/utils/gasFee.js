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
exports.CodefiGasFees = void 0;
/*
 * @Description:
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-12-28 20:46:15
 * @LastEditors: cejay
 * @LastEditTime: 2022-12-28 21:01:27
 */
const axios_1 = __importDefault(require("axios"));
class CodefiGasFees {
    /*
    https://gas-api.metaswap.codefi.network/networks/1/suggestedGasFees
    https://gas-api.metaswap.codefi.network/networks/1/gasPrices
    */
    static getEIP1559GasFees(chainId) {
        return __awaiter(this, void 0, void 0, function* () {
            try {
                const response = yield axios_1.default.get(`https://gas-api.metaswap.codefi.network/networks/${chainId}/suggestedGasFees`);
                if (response.status === 200) {
                    const gas = response.data;
                    if (gas) {
                        return gas;
                    }
                }
            }
            catch (error) {
                console.log(error);
            }
            return null;
        });
    }
    static getLegacyGasPrices(chainId) {
        return __awaiter(this, void 0, void 0, function* () {
            try {
                const response = yield axios_1.default.get(`https://gas-api.metaswap.codefi.network/networks/${chainId}/gasPrices`);
                if (response.status === 200) {
                    const gas = response.data;
                    if (gas) {
                        return gas;
                    }
                }
            }
            catch (error) {
                console.log(error);
            }
            return null;
        });
    }
}
exports.CodefiGasFees = CodefiGasFees;
//# sourceMappingURL=gasFee.js.map