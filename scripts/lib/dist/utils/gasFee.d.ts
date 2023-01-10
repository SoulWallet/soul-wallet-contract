import { SuggestedGasFees, gasPrices } from '../entity/codefiGasFees';
export declare class CodefiGasFees {
    static getEIP1559GasFees(chainId: number): Promise<SuggestedGasFees | null>;
    static getLegacyGasPrices(chainId: number): Promise<gasPrices | null>;
}
