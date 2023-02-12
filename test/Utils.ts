/*
 * @Description: 
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-12-27 20:58:00
 * @LastEditors: cejay
 * @LastEditTime: 2023-02-11 13:21:00
 */

import { ethers } from "ethers";
import { defaultAbiCoder } from 'ethers/lib/utils'
import * as ethUtil from 'ethereumjs-util';

class Utils {

    static signMessage(msg: string, privateKey: string) {
        const messageHex = Buffer.from(ethers.utils.arrayify(msg)).toString('hex');
        const personalMessage = ethUtil.hashPersonalMessage(ethUtil.toBuffer(ethUtil.addHexPrefix(messageHex)));
        const _privateKey = Buffer.from(privateKey.substring(2), "hex");
        const signature1 = ethUtil.ecsign(personalMessage, _privateKey);
        return ethUtil.toRpcSig(signature1.v, signature1.r, signature1.s);
    }

    static recoverAddress(msg: string, signature: string) {
        const messageHex = Buffer.from(ethers.utils.arrayify(msg)).toString('hex');
        const personalMessage = ethUtil.hashPersonalMessage(ethUtil.toBuffer(ethUtil.addHexPrefix(messageHex)));
        const signature1 = ethUtil.fromRpcSig(signature);
        const publicKey = ethUtil.ecrecover(personalMessage, signature1.v, signature1.r, signature1.s);
        const address = ethUtil.publicToAddress(publicKey).toString('hex');
        return ethUtil.addHexPrefix(address);
    }



}

export { Utils };