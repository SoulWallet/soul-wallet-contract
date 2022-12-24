/**
 * fork from:
 * @link https://github.com/eth-infinitism/account-abstraction/blob/develop/test/UserOp.ts
 */
import { UserOperation } from '../entity/userOperation';
import { guardianSignature } from './guardian';
export declare function packUserOp(op: UserOperation, forSignature?: boolean): string;
export declare function getRequestId(op: UserOperation, entryPointAddress: string, chainId: number): string;
/**
 * sign a user operation with the given private key
 * @param op
 * @param entryPointAddress
 * @param chainId
 * @param privateKey
 * @returns signature
 */
export declare function signUserOp(op: UserOperation, entryPointAddress: string, chainId: number, privateKey: string): string;
/**
 * sign a user operation with the requestId signature
 * @param signAddress signer address
 * @param signature the signature of the requestId
 * @returns signature
 */
export declare function signUserOpWithPersonalSign(signAddress: string, signature: string): string;
/**
 * sign a user operation with guardian signatures
 * @param signatures guardian signatures
 * @param guardianLogicAddress guardian logic contract address
 * @param guardians guardian addresses
 * @param threshold threshold
 * @param salt salt
 * @param create2Factory create2 factory address
 * @param guardianAddress guardian contract address,if provided will check if equal to the calculated guardian address
 * @returns signature
 */
export declare function packGuardiansSign(signature: guardianSignature[], guardianLogicAddress: string, guardians: string[], threshold: number, salt: string, create2Factory: string, guardianAddress?: string | undefined): string;
/**
 * sign a user operation with guardian signatures
 * @param guardianAddress guardian contract address
 * @param signatures guardian signatures
 * @param initCode intiCode must given when the guardian contract is not deployed
 * @returns
 */
export declare function packGuardiansSignByInitCode(guardianAddress: string, signature: guardianSignature[], initCode?: string): string;
export declare function payMasterSignHash(op: UserOperation): string;
