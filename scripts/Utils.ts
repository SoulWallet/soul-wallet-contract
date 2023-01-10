/*
 * @Description: 
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-12-27 20:58:00
 * @LastEditors: cejay
 * @LastEditTime: 2022-12-27 20:59:22
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



}

export { Utils };