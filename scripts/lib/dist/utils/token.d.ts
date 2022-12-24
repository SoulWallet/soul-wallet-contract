import { UserOperation } from "../entity/userOperation";
import { ethers } from "ethers";
import { NumberLike } from "../defines/numberLike";
export declare class Token {
    static createOp(etherProvider: ethers.providers.BaseProvider, walletAddress: string, nonce: number, entryPointAddress: string, paymasterAndData: string, maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike, callContract: string, encodeABI: string, value?: string): Promise<UserOperation | null>;
}
export declare class ERC20 {
    private static getContract;
    static approve(etherProvider: ethers.providers.BaseProvider, walletAddress: string, nonce: number, entryPointAddress: string, paymasterAddress: string, maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike, token: string, _spender: string, _value: string): Promise<UserOperation | null>;
    static transferFrom(etherProvider: ethers.providers.BaseProvider, walletAddress: string, nonce: number, entryPointAddress: string, paymasterAddress: string, maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike, token: string, _from: string, _to: string, _value: string): Promise<UserOperation | null>;
    static transfer(etherProvider: ethers.providers.BaseProvider, walletAddress: string, nonce: number, entryPointAddress: string, paymasterAddress: string, maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike, token: string, _to: string, _value: string): Promise<UserOperation | null>;
}
export declare class ERC721 {
    private static getContract;
    static approve(etherProvider: ethers.providers.BaseProvider, walletAddress: string, nonce: number, entryPointAddress: string, paymasterAddress: string, maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike, token: string, _spender: string, _tokenId: string): Promise<UserOperation | null>;
    static transferFrom(etherProvider: ethers.providers.BaseProvider, walletAddress: string, nonce: number, entryPointAddress: string, paymasterAddress: string, maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike, token: string, _from: string, _to: string, _tokenId: string): Promise<UserOperation | null>;
    static transfer(etherProvider: ethers.providers.BaseProvider, walletAddress: string, nonce: number, entryPointAddress: string, paymasterAddress: string, maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike, token: string, _to: string, _tokenId: string): Promise<UserOperation | null>;
    static safeTransferFrom(etherProvider: ethers.providers.BaseProvider, walletAddress: string, nonce: number, entryPointAddress: string, paymasterAddress: string, maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike, token: string, _from: string, _to: string, _tokenId: string): Promise<UserOperation | null>;
    static setApprovalForAll(etherProvider: ethers.providers.BaseProvider, walletAddress: string, nonce: number, entryPointAddress: string, paymasterAddress: string, maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike, token: string, _operator: string, _approved: boolean): Promise<UserOperation | null>;
}
export declare class ERC1155 {
    private static getContract;
    static safeTransferFrom(etherProvider: ethers.providers.BaseProvider, walletAddress: string, nonce: number, entryPointAddress: string, paymasterAddress: string, maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike, token: string, _from: string, _to: string, _id: string, _value: string, _data: string): Promise<UserOperation | null>;
    static safeBatchTransferFrom(etherProvider: ethers.providers.BaseProvider, walletAddress: string, nonce: number, entryPointAddress: string, paymasterAddress: string, maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike, token: string, _from: string, _to: string, _ids: string, _values: string, _data: string): Promise<UserOperation | null>;
    static setApprovalForAll(etherProvider: ethers.providers.BaseProvider, walletAddress: string, nonce: number, entryPointAddress: string, paymasterAddress: string, maxFeePerGas: NumberLike, maxPriorityFeePerGas: NumberLike, token: string, _operator: string, _approved: boolean): Promise<UserOperation | null>;
}
export declare class ETH {
    static transfer(etherProvider: ethers.providers.BaseProvider, walletAddress: string, nonce: number, entryPointAddress: string, paymasterAddress: string, maxFeePerGas: number, maxPriorityFeePerGas: number, to: string, value: string): Promise<UserOperation | null>;
}
