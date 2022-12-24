/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type { PromiseOrValue } from "../../../common";
import type {
  GuardianControl,
  GuardianControlInterface,
} from "../../../contracts/guardian/GuardianControl";

const _abi = [
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "newGuardian",
        type: "address",
      },
      {
        indexed: false,
        internalType: "address",
        name: "oldGuardian",
        type: "address",
      },
    ],
    name: "GuardianSet",
    type: "event",
  },
  {
    inputs: [],
    name: "guardianInfo",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
      {
        internalType: "address",
        name: "",
        type: "address",
      },
      {
        internalType: "uint64",
        name: "",
        type: "uint64",
      },
      {
        internalType: "uint32",
        name: "",
        type: "uint32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "guardianProcess",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
];

const _bytecode =
  "0x60a06040526040516100109061004b565b604051809103906000f08015801561002c573d6000803e3d6000fd5b506001600160a01b031660805234801561004557600080fd5b50610058565b6102338061042083390190565b6080516103b0610070600039600050506103b06000f3fe608060405234801561001057600080fd5b50600436106100365760003560e01c80637426bbc01461003b5780639191935e14610095575b600080fd5b6100436100ad565b6040805173ffffffffffffffffffffffffffffffffffffffff958616815294909316602085015267ffffffffffffffff9091169183019190915263ffffffff1660608201526080015b60405180910390f35b61009d6101f2565b604051901515815260200161008c565b6040805160a0810182527ff8a710ee80f631cf345664111f4640826662740a1425b833ce4638e14a4e7edc805473ffffffffffffffffffffffffffffffffffffffff90811683527ff8a710ee80f631cf345664111f4640826662740a1425b833ce4638e14a4e7edd54908116602084015274010000000000000000000000000000000000000000810467ffffffffffffffff16838501527c0100000000000000000000000000000000000000000000000000000000900463ffffffff166060830152825161064081019384905260009384938493849384936080840191907ff8a710ee80f631cf345664111f4640826662740a1425b833ce4638e14a4e7ede9060329082845b8154815260200190600101908083116101b357505050919092525050815160208301516040840151606090940151919990985092965094509092505050565b60007ff8a710ee80f631cf345664111f4640826662740a1425b833ce4638e14a4e7edc61021e81610224565b91505090565b600181015460009074010000000000000000000000000000000000000000900467ffffffffffffffff161580159061028357506001820154427401000000000000000000000000000000000000000090910467ffffffffffffffff1610155b156102dd576001820180547fffffffff0000000000000000ffffffffffffffffffffffffffffffffffffffff81169091556102d590839073ffffffffffffffffffffffffffffffffffffffff166102e5565b506001919050565b506000919050565b81546040805173ffffffffffffffffffffffffffffffffffffffff808516825290921660208301527fc3ce29e3ab42e524b6f6f1b4d3674898d503ee3577a64ac87b555904ebc14138910160405180910390a181547fffffffffffffffffffffffff00000000000000000000000000000000000000001673ffffffffffffffffffffffffffffffffffffffff9190911617905556fea2646970667358221220c3c5008d6ce0389ddf22418a1babf5c6e391b6b09b0f8b67f97653cc76fead1564736f6c63430008110033608060405234801561001057600080fd5b50610213806100206000396000f3fe608060405234801561001057600080fd5b506004361061002b5760003560e01c8063570e1a3614610030575b600080fd5b61004361003e3660046100f9565b61006c565b60405173ffffffffffffffffffffffffffffffffffffffff909116815260200160405180910390f35b60008061007c601482858761016b565b61008591610195565b60601c90506000610099846014818861016b565b8080601f016020809104026020016040519081016040528093929190818152602001838380828437600092018290525084519495509360209350849250905082850182875af190506000519350806100f057600093505b50505092915050565b6000806020838503121561010c57600080fd5b823567ffffffffffffffff8082111561012457600080fd5b818501915085601f83011261013857600080fd5b81358181111561014757600080fd5b86602082850101111561015957600080fd5b60209290920196919550909350505050565b6000808585111561017b57600080fd5b8386111561018857600080fd5b5050820193919092039150565b7fffffffffffffffffffffffffffffffffffffffff00000000000000000000000081358181169160148510156101d55780818660140360031b1b83161692505b50509291505056fea264697066735822122027016fd42ee16336a5dfa982494f92cb77bd4ee4201d451ae19d7c4c989fbff264736f6c63430008110033";

type GuardianControlConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: GuardianControlConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class GuardianControl__factory extends ContractFactory {
  constructor(...args: GuardianControlConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  override deploy(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<GuardianControl> {
    return super.deploy(overrides || {}) as Promise<GuardianControl>;
  }
  override getDeployTransaction(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  override attach(address: string): GuardianControl {
    return super.attach(address) as GuardianControl;
  }
  override connect(signer: Signer): GuardianControl__factory {
    return super.connect(signer) as GuardianControl__factory;
  }

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): GuardianControlInterface {
    return new utils.Interface(_abi) as GuardianControlInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): GuardianControl {
    return new Contract(address, _abi, signerOrProvider) as GuardianControl;
  }
}