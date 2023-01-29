export declare class TokenAndPaymaster {
    static pack(tokenAndPaymaster: ITokenAndPaymaster[]): string;
    static unpack(data: string): ITokenAndPaymaster[];
}
export interface ITokenAndPaymaster {
    token: string;
    paymaster: string;
}
