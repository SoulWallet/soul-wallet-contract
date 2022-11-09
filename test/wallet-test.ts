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
  GuardianMultiSigWallet__factory,
  GuardianFactory__factory,
} from "../src/types/index";
import { UserOperation } from "./userOperation";
import { signUserOp, getRequestId, signGuardianOp, fillUserOp } from "./userOp";

import {
  getCreate2Address,
  hexlify,
  hexZeroPad,
  keccak256,
} from "ethers/lib/utils";
import { EIP4337Lib } from "soul-wallet-lib/dist/exportLib/EIP4337Lib";
import fs from "fs";
import { Wallet } from "ethers";

describe("WalletTest", function () {
  let addr1: any, addr2: any, addr3: any, addr4: any, addr5: any, addr6: any;
  let owner: Wallet, ownerPrivateKey: string;
  let guardian1: Wallet, guardian1PrivateKey: string;
  let guardian2: Wallet, guardian2PrivateKey: string;
  let guardian3: Wallet, guardian3PrivateKey: string;
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
    let contractCreateInitCode = `${WalletProxy__factory.bytecode.slice(
      2
    )}${constructorArg.slice(2)}`;
    smartWalletAddress = await create2(
      create2Factory.address,
      salt,
      `0x${contractCreateInitCode}`
    );

    let ifaceCreate2 = new hre.ethers.utils.Interface(
      Create2Factory__factory.abi
    );
    const initializationDataCreate2 = ifaceCreate2.encodeFunctionData(
      "deploy",
      [`0x${contractCreateInitCode}`, salt]
    );

    const initCode = `${
      create2Factory.address
    }${initializationDataCreate2.slice(2)}`;
    await entryPoint.connect(addr1).depositTo(smartWalletAddress, {
      value: hre.ethers.utils.parseEther("10").toString(),
    });

    let userOperation: UserOperation = new UserOperation();
    userOperation.sender = smartWalletAddress;
    userOperation.initCode = initCode;
    userOperation = await fillUserOp(userOperation, entryPoint);

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

  before(async function () {});

  beforeEach(async function () {
    create2Factory = await new Create2Factory__factory(ethersSigner).deploy();
    entryPoint = await new EntryPoint__factory(ethersSigner).deploy(
      hre.ethers.utils.parseEther("1").toString(),
      10
    );
    [addr1, addr2, addr3, addr4, addr5, addr6] = await hre.ethers.getSigners();
    let ownerWallet = hre.ethers.Wallet.createRandom();
    ownerPrivateKey = ownerWallet.privateKey;
    owner = new hre.ethers.Wallet(ownerWallet);

    guardian1 = hre.ethers.Wallet.createRandom();
    guardian1PrivateKey = guardian1.privateKey;

    guardian2 = hre.ethers.Wallet.createRandom();
    guardian2PrivateKey = guardian2.privateKey;

    guardian3 = hre.ethers.Wallet.createRandom();
    guardian3PrivateKey = guardian3.privateKey;

    await deployWallet();
  });

  describe("wallet test", async function () {
    it("test upgrade", async function () {
      const smartWalletContract = await hre.ethers.getContractAt(
        "SmartWallet",
        smartWalletAddress
      );
      let preUpgradeVersion = await smartWalletContract.getVersion();
      expect(preUpgradeVersion).to.equal(1);

      let smartWalletImplementationV2: SmartWalletV2Mock =
        await new SmartWalletV2Mock__factory(ethersSigner).deploy();

      let iface = new hre.ethers.utils.Interface([
        `function upgradeTo(address newImplementation)`,
      ]);
      let functionEncode = iface.encodeFunctionData("upgradeTo", [
        smartWalletImplementationV2.address,
      ]);
      let userOperation: UserOperation = new UserOperation();
      userOperation.sender = smartWalletAddress;
      userOperation.paymasterAndData = "0x";
      userOperation.callData = functionEncode;
      userOperation = await fillUserOp(userOperation, entryPoint);

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

  describe("anonymous guardian test", async function () {
    it("test replace key using anonymous guardian", async function () {
      const smartWalletContract = await hre.ethers.getContractAt(
        "SmartWallet",
        smartWalletAddress
      );

      // deploy guardian multi sig wallet implementation
      let guardianImp = await new GuardianMultiSigWallet__factory(
        ethersSigner
      ).deploy();

      let guardianFactory = await new GuardianFactory__factory(
        ethersSigner
      ).deploy();

      let iface = new hre.ethers.utils.Interface([
        `function initialize(address[] calldata _guardians, uint256 _threshold)`,
      ]);
      // create 2/ 3 multi sig wallet
      let functionEncode = iface.encodeFunctionData("initialize", [
        [guardian1.address, guardian2.address, guardian3.address],
        2,
      ]);

      // calculate getGuardianAddress address
      let calcuateGuardianAddr = await guardianFactory.getGuardianAddress(
        guardianImp.address,
        functionEncode,
        hre.ethers.utils.formatBytes32String("")
      );
      // set guardian to contract
      {
        let smartWalletFactory = await hre.ethers.getContractFactory(
          "SmartWallet"
        );
        functionEncode = smartWalletFactory.interface.encodeFunctionData(
          "updateGuardianRequest",
          [calcuateGuardianAddr]
        );
        let userOperation: UserOperation = new UserOperation();
        userOperation.sender = smartWalletAddress;
        userOperation.paymasterAndData = "0x";
        userOperation.callData = functionEncode;
        userOperation = await fillUserOp(userOperation, entryPoint);

        userOperation.signature = signUserOp(
          userOperation,
          entryPoint.address,
          chainId!,
          ownerPrivateKey
        );
        await entryPoint
          .connect(addr1)
          .handleOps([userOperation], addr1.address);
      }
      // change block time to pass the guardian delay
      await hre.ethers.provider.send("evm_increaseTime", [3600 * 48]);
      await hre.ethers.provider.send("evm_mine", []);

      {
        let smartWalletFactory = await hre.ethers.getContractFactory(
          "SmartWallet"
        );
        functionEncode = smartWalletFactory.interface.encodeFunctionData(
          "updateGuardianConfirmation",
          [calcuateGuardianAddr]
        );
        let userOperation: UserOperation = new UserOperation();
        userOperation.sender = smartWalletAddress;
        userOperation.paymasterAndData = "0x";
        userOperation.callData = functionEncode;
        userOperation = await fillUserOp(userOperation, entryPoint);

        userOperation.signature = signUserOp(
          userOperation,
          entryPoint.address,
          chainId!,
          ownerPrivateKey
        );
        await entryPoint
          .connect(addr1)
          .handleOps([userOperation], addr1.address);
      }

      // deploy guardian multi sig wallet
      await expect(
        guardianFactory.createGuardianMultiSig(
          guardianImp.address,
          [guardian1.address, guardian2.address, guardian3.address],
          2,
          hre.ethers.utils.formatBytes32String("")
        )
      )
        .to.emit(guardianFactory, "NewGuardianCreated")
        .withArgs(calcuateGuardianAddr);

      //create replace key operation
      iface = new hre.ethers.utils.Interface([
        `function transferOwner(address account)`,
      ]);

      functionEncode = iface.encodeFunctionData("transferOwner", [
        addr6.address,
      ]);
      let userOperation: UserOperation = new UserOperation();
      userOperation.sender = smartWalletAddress;
      userOperation.paymasterAndData = "0x";
      userOperation.callData = functionEncode;
      userOperation = await fillUserOp(userOperation, entryPoint);

      let requestId = await getRequestId(
        userOperation,
        entryPoint.address,
        chainId!
      );

      let sig = signGuardianOp(
        requestId,
        [guardian1.privateKey, guardian2.privateKey, guardian3.privateKey],
        calcuateGuardianAddr
      );
      userOperation.signature = sig;
      await entryPoint.connect(addr1).handleOps([userOperation], addr1.address);

      let newOwner = await smartWalletContract.getOwner(0);
      expect(newOwner).to.equal(addr6.address);
    });
  });
});
