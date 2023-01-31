"use strict";
/*
 * @Description:
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2023-01-28 19:43:28
 * @LastEditors: cejay
 * @LastEditTime: 2023-01-28 20:08:30
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.TokenAndPaymaster = void 0;
const ethers_1 = require("ethers");
class TokenAndPaymaster {
    static pack(tokenAndPaymaster) {
        // sort tokenAndPaymaster by token
        tokenAndPaymaster.sort((a, b) => {
            const aTokenBig = ethers_1.BigNumber.from(a.token);
            const bTokenBig = ethers_1.BigNumber.from(b.token);
            if (aTokenBig.eq(bTokenBig)) {
                const aPaymasterBig = ethers_1.BigNumber.from(a.paymaster);
                const bPaymasterBig = ethers_1.BigNumber.from(b.paymaster);
                if (aPaymasterBig.eq(bPaymasterBig)) {
                    return 0;
                }
                else if (aPaymasterBig.lt(bPaymasterBig)) {
                    return -1;
                }
                else {
                    return 1;
                }
            }
            else if (aTokenBig.lt(bTokenBig)) {
                return -1;
            }
            else {
                return 1;
            }
        });
        let result = "0x";
        for (let i = 0; i < tokenAndPaymaster.length; i++) {
            let item = tokenAndPaymaster[i];
            let token = item.token.toLowerCase();
            let paymaster = item.paymaster.toLowerCase();
            // check token and paymaster is eth address
            if (token.length != 42 || paymaster.length != 42) {
                throw new Error("token or paymaster is not valid address");
            }
            result += token.substring(2);
            result += paymaster.substring(2);
        }
        return result;
    }
    static unpack(data) {
        if ((data.length - 2) % 80 == 0) {
            throw new Error("data length is not valid");
        }
        let result = [];
        let count = (data.length - 2) / 80;
        for (let i = 0; i < count; i++) {
            let token = "0x" + data.substring(2 + i * 80, 2 + i * 80 + 40);
            let paymaster = "0x" + data.substring(2 + i * 80 + 40, 2 + i * 80 + 80);
            result.push({
                token: token,
                paymaster: paymaster
            });
        }
        return result;
    }
}
exports.TokenAndPaymaster = TokenAndPaymaster;
//# sourceMappingURL=tokenAndPaymaster.js.map