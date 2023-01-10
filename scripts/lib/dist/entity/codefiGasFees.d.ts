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
