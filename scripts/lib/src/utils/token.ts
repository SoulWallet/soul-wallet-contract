/*
 * @Description: 
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-09-21 21:45:49
 * @LastEditors: cejay
 * @LastEditTime: 2022-12-19 09:53:28
 */
import { UserOperation } from "../entity/userOperation";
import { SimpleWalletContract } from "../contracts/soulWallet";
import { execFromEntryPoint, ERC1155 as erc1155, ERC20 as erc20, ERC721 as erc721 } from "../defines/ABI";
import { ethers } from "ethers";
import { NumberLike } from "../defines/numberLike";
export class Token {

    static async createOp(etherProvider: ethers.providers.BaseProvider, walletAddress: string, nonce: number,
        entryPointAddress: string, paymasterAndData: string,
        maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike, callContract: string, encodeABI: string, value: string = '0') {

        walletAddress = ethers.utils.getAddress(walletAddress);

        let userOperation: UserOperation = new UserOperation();
        userOperation.nonce = nonce;
        userOperation.sender = walletAddress;
        userOperation.paymasterAndData = paymasterAndData;
        userOperation.maxFeePerGas = maxFeePerGas;
        userOperation.maxPriorityFeePerGas = maxPriorityFeePerGas;

        userOperation.callData = new ethers.utils.Interface(execFromEntryPoint)
            .encodeFunctionData("execFromEntryPoint",
                [callContract, value, encodeABI]);
        let gasEstimated = await userOperation.estimateGas(entryPointAddress,
            etherProvider
        );
        if (!gasEstimated) {
            return null;
        }

        return userOperation;
    }
}
export class ERC20 {
    private static getContract(etherProvider: ethers.providers.BaseProvider, contractAddress: string) {
        return new ethers.Contract(contractAddress, erc20, etherProvider);
    }
    static async approve(etherProvider: ethers.providers.BaseProvider, walletAddress: string,
        nonce: number, entryPointAddress: string, paymasterAddress: string,
        maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike, token: string, _spender: string, _value: string) {

        let encodeABI = new ethers.utils.Interface(erc20).encodeFunctionData("approve", [_spender, _value]);
        return await Token.createOp(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, encodeABI);
    }

    static async transferFrom(etherProvider: ethers.providers.BaseProvider, walletAddress: string,
        nonce: number, entryPointAddress: string, paymasterAddress: string,
        maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike, token: string, _from: string, _to: string, _value: string) {

        let encodeABI = new ethers.utils.Interface(erc20).encodeFunctionData("transferFrom", [_from, _to, _value]);
        return await Token.createOp(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, encodeABI);
    }

    static async transfer(etherProvider: ethers.providers.BaseProvider, walletAddress: string,
        nonce: number, entryPointAddress: string, paymasterAddress: string,
        maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike, token: string, _to: string, _value: string) {

        let encodeABI = new ethers.utils.Interface(erc20).encodeFunctionData("transfer", [_to, _value]);
        return await Token.createOp(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, encodeABI);
    }
}

export class ERC721 {
    private static getContract(etherProvider: ethers.providers.BaseProvider, contractAddress: string) {
        return new ethers.Contract(contractAddress, erc721, etherProvider);
    }
    static async approve(etherProvider: ethers.providers.BaseProvider, walletAddress: string,
        nonce: number, entryPointAddress: string, paymasterAddress: string,
        maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike, token: string, _spender: string, _tokenId: string) {

        let encodeABI = new ethers.utils.Interface(erc721).encodeFunctionData("approve", [_spender, _tokenId]);
        return await Token.createOp(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, encodeABI);
    }

    static async transferFrom(etherProvider: ethers.providers.BaseProvider, walletAddress: string,
        nonce: number, entryPointAddress: string, paymasterAddress: string,
        maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike, token: string, _from: string, _to: string, _tokenId: string) {

        let encodeABI = new ethers.utils.Interface(erc721).encodeFunctionData("transferFrom", [_from, _to, _tokenId]);
        return await Token.createOp(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, encodeABI);
    }

    static async transfer(etherProvider: ethers.providers.BaseProvider, walletAddress: string,
        nonce: number, entryPointAddress: string, paymasterAddress: string,
        maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike, token: string, _to: string, _tokenId: string) {

        let encodeABI = new ethers.utils.Interface(erc721).encodeFunctionData("transfer", [_to, _tokenId]);
        return await Token.createOp(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, encodeABI);
    }

    static async safeTransferFrom(etherProvider: ethers.providers.BaseProvider, walletAddress: string,
        nonce: number, entryPointAddress: string, paymasterAddress: string,
        maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike, token: string, _from: string, _to: string, _tokenId: string) {

        let encodeABI = new ethers.utils.Interface(erc721).encodeFunctionData("safeTransferFrom", [_from, _to, _tokenId]);
        return await Token.createOp(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, encodeABI);
    }

    static async setApprovalForAll(etherProvider: ethers.providers.BaseProvider, walletAddress: string,
        nonce: number, entryPointAddress: string, paymasterAddress: string,
        maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike, token: string, _operator: string, _approved: boolean) {

        let encodeABI = new ethers.utils.Interface(erc721).encodeFunctionData("setApprovalForAll", [_operator, _approved]);
        return await Token.createOp(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, encodeABI);
    }


}

export class ERC1155 {
    private static getContract(etherProvider: ethers.providers.BaseProvider, contractAddress: string) {
        return new ethers.Contract(contractAddress, erc1155, etherProvider);
    }
    static async safeTransferFrom(etherProvider: ethers.providers.BaseProvider, walletAddress: string,
        nonce: number, entryPointAddress: string, paymasterAddress: string,
        maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike, token: string, _from: string, _to: string, _id: string, _value: string, _data: string) {

        let encodeABI = new ethers.utils.Interface(erc1155).encodeFunctionData("safeTransferFrom", [_from, _to, _id, _value, _data]);
        return await Token.createOp(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, encodeABI);
    }

    static async safeBatchTransferFrom(etherProvider: ethers.providers.BaseProvider, walletAddress: string,
        nonce: number, entryPointAddress: string, paymasterAddress: string,
        maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike, token: string, _from: string, _to: string, _ids: string, _values: string, _data: string) {

        let encodeABI = new ethers.utils.Interface(erc1155).encodeFunctionData("safeBatchTransferFrom", [_from, _to, _ids, _values, _data]);
        return await Token.createOp(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, encodeABI);
    }

    static async setApprovalForAll(etherProvider: ethers.providers.BaseProvider, walletAddress: string,
        nonce: number, entryPointAddress: string, paymasterAddress: string,
        maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike, token: string, _operator: string, _approved: boolean) {

        let encodeABI = new ethers.utils.Interface(erc1155).encodeFunctionData("setApprovalForAll", [_operator, _approved]);
        return await Token.createOp(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, token, encodeABI);
    }


}

export class ETH {
    static async transfer(etherProvider: ethers.providers.BaseProvider, walletAddress: string,
        nonce: number, entryPointAddress: string, paymasterAddress: string,
        maxFeePerGas: number, maxPriorityFeePerGas: number, to: string, value: string) {

        return await Token.createOp(etherProvider, walletAddress, nonce, entryPointAddress, paymasterAddress, maxFeePerGas, maxPriorityFeePerGas, to, '0x', value);
    }
}