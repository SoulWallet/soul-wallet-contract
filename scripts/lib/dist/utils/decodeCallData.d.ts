export declare class DecodeCallData {
    private static instance;
    private bytes4Methods;
    private _saveToStorage;
    private _readFromStorage;
    private constructor();
    static new(): DecodeCallData;
    /**
     * set saveToStorage function & readFromStorage function
     * @param saveToStorage async function
     * @param readFromStorage async function
     */
    setStorage(saveToStorage: (key: string, value: string) => any, readFromStorage: (key: string) => string | null): void;
    private saveToStorage;
    private readFromStorage;
    private read4BytesMethod;
    /**
     * decode call data
     * @param callData call data
     * @returns
     */
    decode(callData: string): Promise<IDecode | null>;
}
interface IDecode {
    functionName: string;
    functionSignature: string;
    params: any;
}
export {};
