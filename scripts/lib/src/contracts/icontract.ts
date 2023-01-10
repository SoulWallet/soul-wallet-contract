/*
 * @Description: 
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-08-05 21:02:15
 * @LastEditors: cejay
 * @LastEditTime: 2022-11-22 23:11:19
 */

import { JsonFragment, Fragment } from '@ethersproject/abi'

export interface IContract {
    ABI: ReadonlyArray<Fragment | JsonFragment | string>;
    bytecode: string;
}