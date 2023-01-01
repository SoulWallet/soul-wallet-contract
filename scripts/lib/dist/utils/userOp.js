"use strict";
/**
 * fork from:
 * @link https://github.com/eth-infinitism/account-abstraction/blob/develop/test/UserOp.ts
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.payMasterSignHash = exports.packGuardiansSignByInitCode = exports.packGuardiansSign = exports.signUserOpWithPersonalSign = exports.signUserOp = exports.getUserOpHash = exports.packUserOp = void 0;
const utils_1 = require("ethers/lib/utils");
const ethereumjs_util_1 = require("ethereumjs-util");
const ethers_1 = require("ethers");
const Guardian_1 = require("./Guardian");
function encode(typevalues, forSignature) {
    const types = typevalues.map(typevalue => typevalue.type === 'bytes' && forSignature ? 'bytes32' : typevalue.type);
    const values = typevalues.map((typevalue) => typevalue.type === 'bytes' && forSignature ? (0, utils_1.keccak256)(typevalue.val) : typevalue.val);
    return utils_1.defaultAbiCoder.encode(types, values);
}
function packUserOp(op, forSignature = true) {
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
        };
        let encoded = utils_1.defaultAbiCoder.encode([userOpType], [Object.assign(Object.assign({}, op), { signature: '0x' })]);
        // remove leading word (total length) and trailing word (zero-length signature)
        encoded = '0x' + encoded.slice(66, encoded.length - 64);
        return encoded;
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
    ];
    if (!forSignature) {
        // for the purpose of calculating gas cost, also hash signature
        typevalues.push({ type: 'bytes', val: op.signature });
    }
    return encode(typevalues, forSignature);
}
exports.packUserOp = packUserOp;
function getUserOpHash(op, entryPointAddress, chainId) {
    const userOpHash = (0, utils_1.keccak256)(packUserOp(op, true));
    const enc = utils_1.defaultAbiCoder.encode(['bytes32', 'address', 'uint256'], [userOpHash, entryPointAddress, chainId]);
    return (0, utils_1.keccak256)(enc);
}
exports.getUserOpHash = getUserOpHash;
var SignatureMode;
(function (SignatureMode) {
    SignatureMode[SignatureMode["owner"] = 0] = "owner";
    SignatureMode[SignatureMode["guardian"] = 1] = "guardian";
})(SignatureMode || (SignatureMode = {}));
function _signUserOp(op, entryPointAddress, chainId, privateKey) {
    const message = getUserOpHash(op, entryPointAddress, chainId);
    return _signReuestId(message, privateKey);
}
function _signReuestId(userOpHash, privateKey) {
    const msg1 = Buffer.concat([
        Buffer.from('\x19Ethereum Signed Message:\n32', 'ascii'),
        Buffer.from((0, utils_1.arrayify)(userOpHash))
    ]);
    const sig = (0, ethereumjs_util_1.ecsign)((0, ethereumjs_util_1.keccak256)(msg1), Buffer.from((0, utils_1.arrayify)(privateKey)));
    // that's equivalent of:  await signer.signMessage(message);
    // (but without "async"
    const signedMessage1 = (0, ethereumjs_util_1.toRpcSig)(sig.v, sig.r, sig.s);
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
function signUserOp(op, entryPointAddress, chainId, privateKey) {
    const sign = _signUserOp(op, entryPointAddress, chainId, privateKey);
    return signUserOpWithPersonalSign(ethers_1.ethers.utils.computeAddress(privateKey), sign);
}
exports.signUserOp = signUserOp;
/**
 * sign a user operation with the UserOpHash signature
 * @param signAddress signer address
 * @param signature the signature of the UserOpHash
 * @param deadline deadline (block time), default 0
 * @returns signature
 */
function signUserOpWithPersonalSign(signAddress, signature, deadline = 0) {
    const enc = utils_1.defaultAbiCoder.encode(['uint8', 'address', 'uint64', 'bytes'], [
        SignatureMode.owner,
        signAddress,
        deadline,
        signature
    ]);
    return enc;
}
exports.signUserOpWithPersonalSign = signUserOpWithPersonalSign;
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
function packGuardiansSign(deadline, signature, guardianLogicAddress, guardians, threshold, salt, create2Factory, guardianAddress = undefined) {
    const guardianData = Guardian_1.Guaridian.calculateGuardianAndInitCode(guardianLogicAddress, guardians, threshold, salt, create2Factory);
    if (guardianAddress) {
        if (guardianData.address != guardianAddress) {
            throw new Error('guardianAddress is not equal to the calculated guardian address');
        }
    }
    return packGuardiansSignByInitCode(guardianData.address, signature, deadline, guardianData.initCode);
}
exports.packGuardiansSign = packGuardiansSign;
/**
 * sign a user operation with guardian signatures
 * @param guardianAddress guardian contract address
 * @param signatures guardian signatures
 * @param deadline deadline (block time), default 0
 * @param initCode intiCode must given when the guardian contract is not deployed
 * @returns
 */
function packGuardiansSignByInitCode(guardianAddress, signature, deadline = 0, initCode = '0x') {
    const signatureBytes = Guardian_1.Guaridian.guardianSign(signature);
    const guardianCallData = utils_1.defaultAbiCoder.encode(['bytes', 'bytes'], [signatureBytes, initCode]);
    const enc = utils_1.defaultAbiCoder.encode(['uint8', 'address', 'uint64', 'bytes'], [
        SignatureMode.guardian,
        guardianAddress,
        deadline,
        guardianCallData
    ]);
    return enc;
}
exports.packGuardiansSignByInitCode = packGuardiansSignByInitCode;
function payMasterSignHash(op) {
    return (0, utils_1.keccak256)(utils_1.defaultAbiCoder.encode([
        'address',
        'uint256',
        'bytes32',
        'bytes32',
        'uint256',
        'uint',
        'uint',
        'uint256',
        'uint256',
        'address', // paymaster
    ], [
        op.sender,
        op.nonce,
        (0, utils_1.keccak256)(op.initCode),
        (0, utils_1.keccak256)(op.callData),
        op.callGasLimit,
        op.verificationGasLimit,
        op.preVerificationGas,
        op.maxFeePerGas,
        op.maxPriorityFeePerGas,
        op.paymasterAndData.substring(0, 42),
    ]));
}
exports.payMasterSignHash = payMasterSignHash;
//# sourceMappingURL=userOp.js.map