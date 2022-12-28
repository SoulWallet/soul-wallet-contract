/*
 * @Description: 
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-12-28 20:47:28
 * @LastEditors: cejay
 * @LastEditTime: 2022-12-28 20:54:07
 */

export interface fee {
    suggestedMaxPriorityFeePerGas: string;
    suggestedMaxFeePerGas: string;
    minWaitTimeEstimate: number;
    maxWaitTimeEstimate: number;
}

export interface SuggestedGasFees {
    low: fee;
    medium: fee;
    high: fee;
    estimatedBaseFee: string;
    networkCongestion: number;
    latestPriorityFeeRange: string[];
    historicalPriorityFeeRange: string[];
    historicalBaseFeeRange: string[];
    priorityFeeTrend: string;
    baseFeeTrend: string;
}

export interface gasPrices {
    SafeGasPrice: string;
    ProposeGasPrice: string;
    FastGasPrice: string;
}


