/*
 * @Description: 
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-12-28 20:46:15
 * @LastEditors: cejay
 * @LastEditTime: 2022-12-28 21:01:27
 */
import axios from 'axios';
import { SuggestedGasFees, gasPrices } from '../entity/codefiGasFees';

export class CodefiGasFees {
    /* 
    https://gas-api.metaswap.codefi.network/networks/1/suggestedGasFees
    https://gas-api.metaswap.codefi.network/networks/1/gasPrices
    */
    static async getEIP1559GasFees(chainId: number): Promise<SuggestedGasFees | null> {
        try {
            const response = await axios.get(`https://gas-api.metaswap.codefi.network/networks/${chainId}/suggestedGasFees`);
            if (response.status === 200) {
                const gas = response.data as SuggestedGasFees;
                if (gas) {
                    return gas;
                }
            }
        } catch (error) {
            console.log(error);
        }

        return null;
    }
    static async getLegacyGasPrices(chainId: number): Promise<gasPrices | null> {
        try {
            const response = await axios.get(`https://gas-api.metaswap.codefi.network/networks/${chainId}/gasPrices`);
            if (response.status === 200) {
                const gas = response.data as gasPrices;
                if (gas) {
                    return gas;
                }
            }
        } catch (error) {
            console.log(error);
        }
        return null;
    }
}

