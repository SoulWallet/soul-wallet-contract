/*
 * @Description: 
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-12-19 09:43:11
 * @LastEditors: cejay
 * @LastEditTime: 2022-12-26 11:01:08
 */

import { BigNumber } from "@ethersproject/bignumber";

export type NumberLike = number | string;//| BigNumber;


export function isNumberLike(value: any): boolean {
    return typeof value === "number" || typeof value === "string";
}

export function toDecString(value: NumberLike): string {
    if (typeof value === "number") {
        return value.toString();
    } if (value.startsWith("0x")) {
        return BigNumber.from(value).toString();
    }
    return value;
}