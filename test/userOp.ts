/**
 * fork from:
 * @link https://github.com/eth-infinitism/account-abstraction/blob/develop/test/UserOp.ts
 */

 import { arrayify, defaultAbiCoder, keccak256, hexDataSlice} from 'ethers/lib/utils'
 import { ecsign, toRpcSig, keccak256 as keccak256_buffer } from 'ethereumjs-util'
 import { UserOperation } from './userOperation'
 import Web3 from 'web3'
 import {Signer, utils, ethers, providers, BigNumber, Contract} from 'ethers'
 import {
  EntryPoint,
  SmartWallet,
} from "../src/types/index";
export const AddressZero = ethers.constants.AddressZero;
 
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

 export interface GuardianSignature {
  signer: string,
  data: string
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


 export function signGuardianOp( requestId: string,  privateKeys: string[], guardian: string): string {
  let guardianSignature: GuardianSignature[]= new Array();
  for(let i=0; i < privateKeys.length; i++) {
    let privateKey = privateKeys[i];
    let msg1 = Buffer.concat([
      Buffer.from('\x19Ethereum Signed Message:\n32', 'ascii'),
      Buffer.from(arrayify(requestId))
    ])
  
    let sig = ecsign(keccak256_buffer(msg1), Buffer.from(arrayify(privateKey)))
    // that's equivalent of:  await signer.signMessage(message);
    // (but without "async"
    let signedMessage1 = toRpcSig(sig.v, sig.r, sig.s);
    var wallet = new ethers.Wallet(privateKey);
    let signature: GuardianSignature = {
      signer: wallet.address,
      data: signedMessage1
    };
    guardianSignature.push(signature);
  }
  let signatureBytes = buildGuardiansSignatureBytes(guardianSignature);
  const enc = defaultAbiCoder.encode(['uint8', 'tuple(address,bytes)[]'], [SignatureMode.guardians, [[
    guardian,
    signatureBytes
  ]]]);
  return enc;
}

 
 export const buildGuardiansSignatureBytes = (signatures: GuardianSignature[]): string => {
  signatures.sort((left, right) => left.signer.toLowerCase().localeCompare(right.signer.toLowerCase()))
  let signatureBytes = "0x"
  for (const sig of signatures) {
      signatureBytes += sig.data.slice(2)
  }
  return signatureBytes
}

export const signHash = async (signer: Signer, hash: string): Promise<GuardianSignature> => {
  const typedDataHash = utils.arrayify(hash)
  const signerAddress = await signer.getAddress()
  return {
      signer: signerAddress,
      data: (await signer.signMessage(typedDataHash))
  }
}

export const DefaultsForUserOp: UserOperation = {
  sender: AddressZero,
  nonce: 0,
  initCode: '0x',
  callData: '0x',
  callGasLimit: 0,
  verificationGasLimit: 200000,
  preVerificationGas: 21000,
  maxFeePerGas: 0,
  maxPriorityFeePerGas: 1e9,
  paymasterAndData: '0x',
  signature: '0x'
}

export async function fillUserOp (op: Partial<UserOperation>, entryPoint?: EntryPoint): Promise<UserOperation> {
  const op1 = { ...op }
  const provider = entryPoint?.provider
  if (op.initCode != "0x") {
    const initAddr = hexDataSlice(op1.initCode!, 0, 20)
    const initCallData = hexDataSlice(op1.initCode!, 20)
    if (op1.nonce == null) op1.nonce = 0
    if (provider == null) throw new Error('no entrypoint/provider')
    op1.sender = await entryPoint!.connect(AddressZero).callStatic.getSenderAddress(op1.initCode!)
    if (op1.verificationGasLimit == 0) {
      if (provider == null) throw new Error('no entrypoint/provider')
      console.log('verificationGasLimit trying to estimate')
      const initEstimate = await provider.estimateGas({
        from: entryPoint?.address,
        to: initAddr,
        data: initCallData,
        gasLimit: 10e9
      })
      op1.verificationGasLimit = DefaultsForUserOp.verificationGasLimit + Number(initEstimate.toString())
    }
  }
  if (op1.nonce == 0 && op1.initCode == "0x") {
    if (provider == null) throw new Error('must have entryPoint to autofill nonce')
    const c = new Contract(op.sender!, ['function nonce() public view returns (uint256)'], provider)
    let nonce = await c.nonce()
    op1.nonce = Number(nonce.toString())
  }
  if (op1.callGasLimit == 0) {
    if (provider == null) throw new Error('must have entryPoint for callGasLimit estimate')
    const gasEstimated = await provider.estimateGas({
      from: entryPoint?.address,
      to: op1.sender,
      data: op1.callData
    })

    op1.callGasLimit = gasEstimated.add(100000).toNumber()
  }
  if (op1.maxFeePerGas == 0) {
    if (provider == null) throw new Error('must have entryPoint to autofill maxFeePerGas')
    const block = await provider.getBlock('latest')
    op1.maxFeePerGas = block.baseFeePerGas!.add(op1.maxPriorityFeePerGas ?? DefaultsForUserOp.maxPriorityFeePerGas).toNumber()
  }
  if (op1.maxPriorityFeePerGas == 0) {
    op1.maxPriorityFeePerGas = DefaultsForUserOp.maxPriorityFeePerGas
  }
  const op2 = fillUserOpDefaults(op1)
  if (op2.preVerificationGas.toString() === '0') {
    op2.preVerificationGas = callDataCost(packUserOp(op2, false))
  }
  // op2.callGasLimit = 10e6;
  op2.verificationGasLimit = 11e6;
  return op2
}
export function fillUserOpDefaults (op: Partial<UserOperation>, defaults = DefaultsForUserOp): UserOperation {
  const partial: any = { ...op }
  // we want "item:undefined" to be used from defaults, and not override defaults, so we must explicitly
  // remove those so "merge" will succeed.
  for (const key in partial) {
    if (partial[key] == null) {
      // eslint-disable-next-line @typescript-eslint/no-dynamic-delete
      delete partial[key]
    }
  }
  const filled = { ...defaults, ...partial }
  return filled
}

export function callDataCost (data: string): number {
  return ethers.utils.arrayify(data)
    .map(x => x === 0 ? 4 : 16)
    .reduce((sum, x) => sum + x)
}