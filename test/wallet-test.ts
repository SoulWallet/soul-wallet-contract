import { expect } from "chai";
import hre from "hardhat";

import {
  EntryPoint,
  Create2Factory,
  SmartWallet,
  Create2Factory__factory,
  EntryPoint__factory,
  SmartWallet__factory,
  WalletProxy__factory,
  SmartWalletV2Mock__factory,
  SmartWalletV2Mock,
} from "../src/types/index";
import { UserOperation } from "./userOperation";
import { signUserOp } from "./userOp";

import {
  getCreate2Address,
  hexlify,
  hexZeroPad,
  keccak256,
} from "ethers/lib/utils";
import { EIP4337Lib } from "soul-wallet-lib/dist/exportLib/EIP4337Lib";
import fs from "fs";

describe("WalletTest", function () {
  let addr1: any, addr2: any, addr3: any;
  let owner, ownerPrivateKey;
  let create2Factory: Create2Factory;
  let entryPoint: EntryPoint;
  let smartWalletAddress;
  const chainId = hre.network.config.chainId;
  const ethersSigner = hre.ethers.provider.getSigner();

  async function advanceBlockTo(blockNumber) {
    for (
      let i = await hre.ethers.provider.getBlockNumber();
      i < blockNumber;
      i++
    ) {
      await advanceBlock();
    }
  }

  async function advanceBlock() {
    return hre.ethers.provider.send("evm_mine", []);
  }

  async function create2(from, salt, initCode) {
    const saltBytes32 = hexZeroPad(hexlify(salt), 32);
    const initCodeHash = keccak256(initCode);
    return getCreate2Address(from, saltBytes32, initCodeHash);
  }

  async function deployWallet() {
    let smartWalletImplementation: SmartWallet = await new SmartWallet__factory(
      ethersSigner
    ).deploy();
    let iface = new hre.ethers.utils.Interface(SmartWallet__factory.abi);
    const initializationData = iface.encodeFunctionData("initialize", [
      entryPoint.address,
      owner.address,
      "0x0000000000000000000000000000000000000000",
      "0x0000000000000000000000000000000000000000",
    ]);

    let constructorArg = hre.ethers.utils.defaultAbiCoder.encode(
      ["address", "bytes"],
      [smartWalletImplementation.address, initializationData]
    );

    const salt = "0x".padEnd(66, "0");
    console.log(`create2Factory address`, create2Factory.address);
    let contractCreateInitCode = `${WalletProxy__factory.bytecode.slice(2)}${constructorArg.slice(2)}`
    smartWalletAddress = await create2(create2Factory.address, salt, `0x${contractCreateInitCode}`);

    let ifaceCreate2 = new hre.ethers.utils.Interface(Create2Factory__factory.abi);
    const initializationDataCreate2 = ifaceCreate2.encodeFunctionData("deploy", [
      `0x${contractCreateInitCode}`,salt
    ]);

    const initCode = `${
      create2Factory.address
    }${initializationDataCreate2.slice(2)}`;
    await entryPoint.connect(addr1).depositTo(smartWalletAddress, {
      value: hre.ethers.utils.parseEther("10").toString(),
    });

    let userOperation: UserOperation = new UserOperation();
    userOperation.sender = smartWalletAddress;
    userOperation.initCode = initCode;
    userOperation.callGasLimit = 10e6;
    userOperation.verificationGasLimit = 11e6;
    userOperation.preVerificationGas = 12e6;
    userOperation.maxFeePerGas = 12e9;
    userOperation.maxPriorityFeePerGas = 12e9;

    userOperation.signature = signUserOp(
      userOperation,
      entryPoint.address,
      chainId!,
      ownerPrivateKey
    );
    await entryPoint.connect(addr1).handleOps([userOperation], addr1.address, {
      gasLimit: 29000000,
    });
  }

  before(async function () {
    create2Factory = await new Create2Factory__factory(ethersSigner).deploy();
    entryPoint = await new EntryPoint__factory(ethersSigner).deploy(
      hre.ethers.utils.parseEther("1").toString(),
      10
    );
    [addr1, addr2, addr3] = await hre.ethers.getSigners();
    let ownerWallet = hre.ethers.Wallet.createRandom();
    ownerPrivateKey = ownerWallet.privateKey;
    owner = new hre.ethers.Wallet(ownerWallet);
    await deployWallet();
  });

  beforeEach(async function () {});

  describe("wallet test", async function () {
    it("test upgrade", async function () {
      console.log(`smartWalletAddress`, smartWalletAddress)
      const smartWalletContract = await hre.ethers.getContractAt(
        "SmartWallet",
        smartWalletAddress
      );
      let preUpgradeVersion = await smartWalletContract.getVersion();
      expect(preUpgradeVersion).to.equal(1);
    
      let smartWalletImplementationV2: SmartWalletV2Mock= await new SmartWalletV2Mock__factory(
        ethersSigner
      ).deploy();

      let iface = new hre.ethers.utils.Interface([
        `function upgradeTo(address newImplementation)`,
      ]);
      let functionEncode = iface.encodeFunctionData("upgradeTo", [
        smartWalletImplementationV2.address,
      ]);
      let userOperation: UserOperation = new UserOperation();
      userOperation.sender = smartWalletAddress;
      userOperation.paymasterAndData = "0x"
      userOperation.callData = functionEncode;
      userOperation.callGasLimit = 10e6;
      userOperation.verificationGasLimit = 11e6;
      userOperation.preVerificationGas = 12e6;
      userOperation.maxFeePerGas = 12e9;
      userOperation.maxPriorityFeePerGas = 12e9;

      userOperation.signature = signUserOp(
        userOperation,
        entryPoint.address,
        chainId!,
        ownerPrivateKey
      );
      await entryPoint.connect(addr1).handleOps([userOperation], addr1.address);
      let afterUpgradeVersion = await smartWalletContract.getVersion();
      expect(afterUpgradeVersion).to.equal(2);
    });
  });
});
