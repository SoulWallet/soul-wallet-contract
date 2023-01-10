/**
 * fork from:
 * @link https://github.com/eth-infinitism/account-abstraction/blob/develop/test/UserOp.ts
 */

import { arrayify, defaultAbiCoder, keccak256, recoverAddress } from 'ethers/lib/utils'
import { ecsign, toRpcSig, fromRpcSig, keccak256 as keccak256_buffer } from 'ethereumjs-util'
import { UserOperation } from '../entity/userOperation'
import { ethers, BigNumber } from "ethers";
import { SimpleWalletContract } from '../contracts/soulWallet'
import { guardianSignature, Guaridian } from './Guardian';

function encode(typevalues: Array<{ type: string, val: any }>, forSignature: boolean): string {
  const types = typevalues.map(typevalue => typevalue.type === 'bytes' && forSignature ? 'bytes32' : typevalue.type)
  const values = typevalues.map((typevalue) => typevalue.type === 'bytes' && forSignature ? keccak256(typevalue.val) : typevalue.val)
  return defaultAbiCoder.encode(types, values)
}

export function packUserOp(op: UserOperation, forSignature = true): string {
  if (forSignature) {
    // lighter signature scheme (must match UserOperation#pack): do encode a zero-length signature, but strip afterwards the appended zero-length value
    const userOpType = {
      components: [
        { type: 'address', name: 'sender' },
        { type: 'uint256', name: 'nonce' },
        { type: 'bytes', name: 'initCode' },
        { type: 'bytes', name: 'callData' },
        { type: 'uint256', name: 'callGasLimit' },
        { type: 'uint256', name: 'verificationGasLimit' },
        { type: 'uint256', name: 'preVerificationGas' },
        { type: 'uint256', name: 'maxFeePerGas' },
        { type: 'uint256', name: 'maxPriorityFeePerGas' },
        { type: 'bytes', name: 'paymasterAndData' },
        { type: 'bytes', name: 'signature' }
      ],
      name: 'userOp',
      type: 'tuple'
    }
    let encoded = defaultAbiCoder.encode([userOpType as any], [{ ...op, signature: '0x' }])
    // remove leading word (total length) and trailing word (zero-length signature)
    encoded = '0x' + encoded.slice(66, encoded.length - 64)
    return encoded
  }
  const typevalues = [
    { type: 'address', val: op.sender },
    { type: 'uint256', val: op.nonce },
    { type: 'bytes', val: op.initCode },
    { type: 'bytes', val: op.callData },
    { type: 'uint256', val: op.callGasLimit },
    { type: 'uint256', val: op.verificationGasLimit },
    { type: 'uint256', val: op.preVerificationGas },
    { type: 'uint256', val: op.maxFeePerGas },
    { type: 'uint256', val: op.maxPriorityFeePerGas },
    { type: 'bytes', val: op.paymasterAndData }
  ]
  if (!forSignature) {
    // for the purpose of calculating gas cost, also hash signature
    typevalues.push({ type: 'bytes', val: op.signature })
  }
  return encode(typevalues, forSignature)
}

export function getUserOpHash(op: UserOperation, entryPointAddress: string, chainId: number): string {
  const userOpHash = keccak256(packUserOp(op, true))
  const enc = defaultAbiCoder.encode(
    ['bytes32', 'address', 'uint256'],
    [userOpHash, entryPointAddress, chainId])
  return keccak256(enc)
}

enum SignatureMode {
  owner = 0,
  guardian = 1
}

function _signUserOp(op: UserOperation, entryPointAddress: string, chainId: number, privateKey: string): string {
  const message = getUserOpHash(op, entryPointAddress, chainId)
  return _signReuestId(message, privateKey);
}

function _signReuestId(userOpHash: string, privateKey: string): string {
  const msg1 = Buffer.concat([
    Buffer.from('\x19Ethereum Signed Message:\n32', 'ascii'),
    Buffer.from(arrayify(userOpHash))
  ])

  const sig = ecsign(keccak256_buffer(msg1), Buffer.from(arrayify(privateKey)))
  // that's equivalent of:  await signer.signMessage(message);
  // (but without "async"
  const signedMessage1 = toRpcSig(sig.v, sig.r, sig.s);
  return signedMessage1;
}


/**
 * sign a user operation with the given private key
 * @param op 
 * @param entryPointAddress 
 * @param chainId 
 * @param privateKey 
 * @returns signature
 */
export function signUserOp(op: UserOperation, entryPointAddress: string, chainId: number, privateKey: string): string {
  const sign = _signUserOp(op, entryPointAddress, chainId, privateKey);
  return signUserOpWithPersonalSign(ethers.utils.computeAddress(privateKey), sign);
}

/**
 * sign a user operation with the UserOpHash signature
 * @param signAddress signer address
 * @param signature the signature of the UserOpHash
 * @param deadline deadline (block time), default 0
 * @returns signature
 */
export function signUserOpWithPersonalSign(signAddress: string, signature: string, deadline = 0) {
  const enc = defaultAbiCoder.encode(['uint8', 'address', 'uint64', 'bytes'],
    [
      SignatureMode.owner,
      signAddress,
      deadline,
      signature
    ]
  );
  return enc;
}



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
export function packGuardiansSign(
  deadline: number,
  signature: guardianSignature[],
  guardianLogicAddress: string, guardians: string[],
  threshold: number, salt: string, create2Factory: string,
  guardianAddress: string | undefined = undefined
): string {
  const guardianData = Guaridian.calculateGuardianAndInitCode(guardianLogicAddress, guardians, threshold, salt, create2Factory);
  if (guardianAddress) {
    if (guardianData.address != guardianAddress) {
      throw new Error('guardianAddress is not equal to the calculated guardian address');
    }
  }
  return packGuardiansSignByInitCode(guardianData.address, signature, deadline,guardianData.initCode);
}



/**
 * sign a user operation with guardian signatures
 * @param guardianAddress guardian contract address
 * @param signatures guardian signatures
 * @param deadline deadline (block time), default 0
 * @param initCode intiCode must given when the guardian contract is not deployed
 * @returns 
 */
export function packGuardiansSignByInitCode(guardianAddress: string, signature: guardianSignature[], deadline = 0, initCode = '0x'
): string {

  const signatureBytes = Guaridian.guardianSign(signature);

  const guardianCallData = defaultAbiCoder.encode(['bytes', 'bytes'], [signatureBytes, initCode]);
  const enc = defaultAbiCoder.encode(['uint8', 'address', 'uint64', 'bytes'],
    [
      SignatureMode.guardian,
      guardianAddress,
      deadline,
      guardianCallData
    ]
  );
  return enc;
}




export function payMasterSignHash(op: UserOperation): string {
  return keccak256(defaultAbiCoder.encode([
    'address', // sender
    'uint256', // nonce
    'bytes32', // initCode
    'bytes32', // callData
    'uint256', // callGas
    'uint', // verificationGas
    'uint', // preVerificationGas
    'uint256', // maxFeePerGas
    'uint256', // maxPriorityFeePerGas
    'address', // paymaster
  ], [
    op.sender,
    op.nonce,
    keccak256(op.initCode),
    keccak256(op.callData),
    op.callGasLimit,
    op.verificationGasLimit,
    op.preVerificationGas,
    op.maxFeePerGas,
    op.maxPriorityFeePerGas,
    op.paymasterAndData.substring(0, 42),
  ]))
}


