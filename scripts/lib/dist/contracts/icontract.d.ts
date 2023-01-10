import { JsonFragment, Fragment } from '@ethersproject/abi';
export interface IContract {
    ABI: ReadonlyArray<Fragment | JsonFragment | string>;
    bytecode: string;
}
