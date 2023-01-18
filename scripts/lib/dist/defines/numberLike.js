"use strict";
/*
 * @Description:
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-12-19 09:43:11
 * @LastEditors: cejay
 * @LastEditTime: 2023-01-17 15:18:26
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.toHexString = exports.toDecString = exports.isNumberLike = void 0;
const bignumber_1 = require("@ethersproject/bignumber");
function isNumberLike(value) {
    return typeof value === "number" || typeof value === "string";
}
exports.isNumberLike = isNumberLike;
function toDecString(value) {
    if (typeof value === "number") {
        return value.toString();
    }
    else if (value.startsWith("0x")) {
        return bignumber_1.BigNumber.from(value).toString();
    }
    return value;
}
exports.toDecString = toDecString;
function toHexString(value) {
    if (typeof value === "number") {
        return value.toString(16);
    }
    else if (value.startsWith("0x")) {
        return value;
    }
    else {
        throw new Error("value is not a number or hex string");
    }
}
exports.toHexString = toHexString;
//# sourceMappingURL=numberLike.js.map