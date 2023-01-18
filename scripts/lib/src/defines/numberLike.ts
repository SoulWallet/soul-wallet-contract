/*
 * @Description: 
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-12-19 09:43:11
 * @LastEditors: cejay
 * @LastEditTime: 2023-01-17 15:18:26
 */

import { BigNumber } from "@ethersproject/bignumber";

export type NumberLike = number | string;//| BigNumber;


export function isNumberLike(value: any): boolean {
    return typeof value === "number" || typeof value === "string";
}

export function toDecString(value: NumberLike): string {
    if (typeof value === "number") {
        return value.toString();
    }else if (value.startsWith("0x")) {
        return BigNumber.from(value).toString();
    }
    return value;
}

export function toHexString(value: NumberLike): string {
    if (typeof value === "number") {
        return value.toString(16);
    }else if (value.startsWith("0x")) {
        return value;
    }else{
        throw new Error("value is not a number or hex string");
    }
}