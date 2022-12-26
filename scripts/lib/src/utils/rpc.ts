/*
 * @Description: 
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-11-16 15:50:52
 * @LastEditors: cejay
 * @LastEditTime: 2022-12-26 20:02:40
 */
import { ethers } from "ethers";
import { EntryPointContract } from "../contracts/entryPoint";
import { UserOperation } from "../entity/userOperation";

export class RPC {
    static eth_sendUserOperation(op: UserOperation, entryPointAddress: string) {
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
    static async waitUserOperation(
        etherProvider: ethers.providers.BaseProvider,
        entryPointAddress: string,
        userOpHash: string,
        timeOut: number = 1000 * 60 * 10,
        fromBlock: number = 0,
        toBlock: number | string = 'pending'
    ): Promise<Array<ethers.Event>> {
        const interval = 1000 * 10;
        const startTime = Date.now();
        // get last block
        let _fromBlock = 0;
        if (fromBlock) {
            _fromBlock = fromBlock;
        } else {
            _fromBlock = await etherProvider.getBlockNumber() - 5;
        }
        const entryPoint = new ethers.Contract(entryPointAddress, EntryPointContract.ABI, etherProvider);

        const UserOperationEventTopic = entryPoint.interface.getEventTopic('UserOperationEvent');

        while (true) {
            const pastEvent: Array<ethers.Event> = await entryPoint.queryFilter({
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
            await new Promise((resolve) => setTimeout(resolve, interval));
        }
    }


}

export interface EventData {
    returnValues: {
        [key: string]: any;
    };
    raw: {
        data: string;
        topics: string[];
    };
    event: string;
    signature: string;
    logIndex: number;
    transactionIndex: number;
    transactionHash: string;
    blockHash: string;
    blockNumber: number;
    address: string;
}