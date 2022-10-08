/**
 * fork from:
 * @link https://github.com/eth-infinitism/account-abstraction/blob/develop/test/UserOp.ts
 */

 import { arrayify, defaultAbiCoder, keccak256 } from 'ethers/lib/utils'
 import { ecsign, toRpcSig, keccak256 as keccak256_buffer } from 'ethereumjs-util'
 import { UserOperation } from './userOperation'
 import Web3 from 'web3'
 
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
     { type: 'bytes', val: op.paymasterAndData },
   ]
   if (!forSignature) {
     // for the purpose of calculating gas cost, also hash signature
     typevalues.push({ type: 'bytes', val: op.signature })
   }
   return encode(typevalues, forSignature)
 }
 
 
 export function getRequestId(op: UserOperation, entryPointAddress: string, chainId: number): string {
   const userOpHash = keccak256(packUserOp(op, true))
   const enc = defaultAbiCoder.encode(
     ['bytes32', 'address', 'uint256'],
     [userOpHash, entryPointAddress, chainId])
   return keccak256(enc)
 }
 
 enum SignatureMode {
   owner = 0,
   guardians = 1
 }
 
 function _signUserOp(op: UserOperation, entryPointAddress: string, chainId: number, privateKey: string): string {
   const message = getRequestId(op, entryPointAddress, chainId)
   const msg1 = Buffer.concat([
     Buffer.from('\x19Ethereum Signed Message:\n32', 'ascii'),
     Buffer.from(arrayify(message))
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
   const enc = defaultAbiCoder.encode(['uint8', 'tuple(address,bytes)[]'], [SignatureMode.owner, [[
     new Web3().eth.accounts.privateKeyToAccount(privateKey).address,
     sign
   ]]]);
   return enc;
 }
 
 