
class UserOperation {

    public sender: string = '';
    public nonce: number = 0;
    public initCode: string = '0x';
    public callData: string = '0x';
    public callGasLimit: number = 0;
    public verificationGasLimit: number = 0;
    public preVerificationGas: number = 21000;
    public maxFeePerGas: number = 0;
    public maxPriorityFeePerGas: number = 0;
    public paymasterAndData: string = '0x';
    public signature: string = '0x';
}



export { UserOperation };