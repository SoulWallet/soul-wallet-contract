/*
 * @Description: 
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-11-07 21:08:08
 * @LastEditors: cejay
 * @LastEditTime: 2022-12-23 19:46:07
 */

import { UserOperation } from "../entity/userOperation";
import { execFromEntryPoint } from "../defines/ABI";
import { ethers } from "ethers";
import { NumberLike } from "../defines/numberLike";

export interface ITransaction {
    data: string;
    from: string;
    gas: string;
    to: string;
    value: string;
}

export class Converter {

    public static async fromTransaction(
        etherProvider: ethers.providers.BaseProvider,
        entryPointAddress: string,
        transcation: ITransaction,
        nonce: number = 0,
        maxFeePerGas: NumberLike = 0,
        maxPriorityFeePerGas: NumberLike = 0,
        paymasterAndData: string = "0x"
    ): Promise<UserOperation | null> {
        const op = new UserOperation();
        op.sender = transcation.from;
        //op.preVerificationGas = 150000;
        op.nonce = nonce;
        op.paymasterAndData = paymasterAndData;
        op.maxFeePerGas = maxFeePerGas;
        op.maxPriorityFeePerGas = maxPriorityFeePerGas;
        op.callGasLimit = parseInt(transcation.gas, 16);

        op.callData = new ethers.utils.Interface(execFromEntryPoint)
            .encodeFunctionData("execFromEntryPoint",
                [transcation.to, transcation.value, transcation.data]);
        let gasEstimated = await op.estimateGas(entryPointAddress,
            etherProvider
        );
        if (!gasEstimated) {
            return null;
        }

        return op;
    }
}