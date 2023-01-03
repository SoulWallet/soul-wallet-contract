/*
 * @Description: 
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-11-16 15:50:52
 * @LastEditors: cejay
 * @LastEditTime: 2023-01-02 22:45:59
 */
import { ethers } from "ethers";
import { UserOperation } from "../entity/userOperation";
import { AddressZero } from "../defines/address";
import { EntryPointContract } from "../contracts/entryPoint";
import { defaultAbiCoder } from "ethers/lib/utils";

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

    static async simulateHandleOp(
        etherProvider: ethers.providers.BaseProvider,
        entryPointAddress: string,
        op: UserOperation) {
        const result = await etherProvider.call({
            from: AddressZero,
            to: entryPointAddress,
            data: new ethers.utils.Interface(EntryPointContract.ABI).encodeFunctionData("simulateHandleOp", [op]),
        });
        // error ExecutionResult(uint256 preOpGas, uint256 paid, uint256 deadline, uint256 paymasterDeadline);
        if (result.startsWith('0xa30fd31e')) {
            const re = defaultAbiCoder.decode(
                ['uint256', 'uint256', 'uint256', 'uint256'],
                '0x' + result.substring(10)
            );
            return {
                preOpGas: re[0],
                paid: re[1],
                deadline: re[2],
                paymasterDeadline: re[3]
            };
        }else if (result.startsWith('0x00fa072b')){
            // FailedOp(uint256,address,string)
            const re = defaultAbiCoder.decode(
                ['uint256', 'address', 'string'],
                '0x' + result.substring(10)
            );
            throw new Error(`FailedOp(${re[0]},${re[1]},${re[2]})`);
        }
        throw new Error(result);

    }

    static async simulateValidation(
        etherProvider: ethers.providers.BaseProvider,
        entryPointAddress: string,
        op: UserOperation) {
        const result = await etherProvider.call({
            from: AddressZero,
            to: entryPointAddress,
            data: new ethers.utils.Interface(EntryPointContract.ABI).encodeFunctionData("simulateValidation", [op]),
        });
        if (result.startsWith('0x5f8f83a2')) {
            // SimulationResult(uint256 preOpGas, uint256 prefund, uint256 deadline, (uint256 stake,uint256 unstakeDelaySec), (uint256 stake,uint256 unstakeDelaySec), (uint256 stake,uint256 unstakeDelaySec))
            const re = defaultAbiCoder.decode(
                ['uint256', 'uint256', 'uint256', '(uint256,uint256)', '(uint256,uint256)', '(uint256,uint256)'],
                '0x' + result.substring(10)
            );
            return {
                preOpGas: re[0],
                prefund: re[1],
                deadline: re[2],
                senderInfo: re[3],
                factoryInfo: re[4],
                paymasterInfo: re[5],
            };
        } else if (result.startsWith("0x00fa072b")) {
            // FailedOp(uint256,address,string)
            const re = defaultAbiCoder.decode(
                ['uint256', 'address', 'string'],
                '0x' + result.substring(10)
            );
            throw new Error(`FailedOp(${re[0]},${re[1]},${re[2]})`);
        } else {
            throw new Error(`simulateValidation failed: ${result}`);
        }
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