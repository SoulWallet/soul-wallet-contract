"use strict";
/*
 * @Description:
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-12-19 09:43:11
 * @LastEditors: cejay
 * @LastEditTime: 2022-12-26 11:01:08
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.toDecString = exports.isNumberLike = void 0;
const bignumber_1 = require("@ethersproject/bignumber");
function isNumberLike(value) {
    return typeof value === "number" || typeof value === "string";
}
exports.isNumberLike = isNumberLike;
function toDecString(value) {
    if (typeof value === "number") {
        return value.toString();
    }
    if (value.startsWith("0x")) {
        return bignumber_1.BigNumber.from(value).toString();
    }
    return value;
}
exports.toDecString = toDecString;
//# sourceMappingURL=numberLike.js.map