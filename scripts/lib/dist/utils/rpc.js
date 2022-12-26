"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.RPC = void 0;
/*
 * @Description:
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-11-16 15:50:52
 * @LastEditors: cejay
 * @LastEditTime: 2022-12-26 20:02:40
 */
const ethers_1 = require("ethers");
const entryPoint_1 = require("../contracts/entryPoint");
class RPC {
    static eth_sendUserOperation(op, entryPointAddress) {
        const op_str = op.toJSON();
        return '{\
            "jsonrpc": "2.0",\
            "method": "eth_sendUserOperation",\
            "params": ['
            + op_str +
            ',"' + entryPointAddress +
            '"],\
            "id": 1\
        }';
    }
    static eth_supportedEntryPoints() {
        return '{\
            "jsonrpc": "2.0",\
            "id": 1,\
            "method": "eth_supportedEntryPoints",\
            "params": []\
          }';
    }
    /**
     * wait for the userOp to be mined
     * @param web3 web3 instance
     * @param entryPointAddress the entryPoint address
     * @param userOpHash the UserOpHash
     * @param timeOut the time out, default:1000 * 60 * 10 ( 10 minutes)
     * @param fromBlock the fromBlock, default: latest - 5
     * @param toBlock the toBlock, default: pending
     * @returns the userOp event array
     */
    static waitUserOperation(etherProvider, entryPointAddress, userOpHash, timeOut = 1000 * 60 * 10, fromBlock = 0, toBlock = 'pending') {
        return __awaiter(this, void 0, void 0, function* () {
            const interval = 1000 * 10;
            const startTime = Date.now();
            // get last block
            let _fromBlock = 0;
            if (fromBlock) {
                _fromBlock = fromBlock;
            }
            else {
                _fromBlock = (yield etherProvider.getBlockNumber()) - 5;
            }
            const entryPoint = new ethers_1.ethers.Contract(entryPointAddress, entryPoint_1.EntryPointContract.ABI, etherProvider);
            const UserOperationEventTopic = entryPoint.interface.getEventTopic('UserOperationEvent');
            while (true) {
                const pastEvent = yield entryPoint.queryFilter({
                    topics: [
                        UserOperationEventTopic,
                        userOpHash
                    ]
                }, _fromBlock, toBlock);
                if (pastEvent && pastEvent.length > 0) {
                    return pastEvent;
                }
                if (Date.now() - startTime > timeOut) {
                    return [];
                }
                yield new Promise((resolve) => setTimeout(resolve, interval));
            }
        });
    }
}
exports.RPC = RPC;
//# sourceMappingURL=rpc.js.map