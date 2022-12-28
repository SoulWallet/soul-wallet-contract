/*
 * @Description: 
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-12-28 20:46:15
 * @LastEditors: cejay
 * @LastEditTime: 2022-12-28 20:57:04
 */
import axios from 'axios';
import { SuggestedGasFees, gasPrices } from '../entity/codefiGasFees';

export class CodefiGasFees {
    /* 
    https://gas-api.metaswap.codefi.network/networks/1/suggestedGasFees
    https://gas-api.metaswap.codefi.network/networks/1/gasPrices
    */
    static async getEIP1559GasFees(chainId: number): Promise<SuggestedGasFees | null> {
        const response = await axios.get(`https://gas-api.metaswap.codefi.network/networks/${chainId}/suggestedGasFees`);
        if (response.status === 200) {
            const gas = response.data as SuggestedGasFees;
            if (gas) {
                return gas;
            }
        }
        return null;
    }
    static async getLegacyGasPrices(chainId: number): Promise<gasPrices | null> {
        const response = await axios.get(`https://gas-api.metaswap.codefi.network/networks/${chainId}/gasPrices`);
        if (response.status === 200) {
            const gas = response.data as gasPrices;
            if (gas) {
                return gas;
            }
        }
        return null;
    }
}

