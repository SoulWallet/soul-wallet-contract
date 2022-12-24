/*
 * @Description: 
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-12-19 09:43:11
 * @LastEditors: cejay
 * @LastEditTime: 2022-12-20 00:23:23
 */

//import { BigNumber } from "@ethersproject/bignumber";

export type NumberLike = number | string;//| BigNumber;


export function isNumberLike(value: any): boolean {
    return typeof value === "number" || typeof value === "string";
}

