const { expect } = require("chai");
const { ethers, userConfig } = require("hardhat");
let smartWalletAbi =
  require("../artifacts/contracts/SmartWallet.sol/SmartWallet.json").abi;

let smartWalletByteCode =
  require("../artifacts/contracts/WalletProxy.sol/WalletProxy.json").bytecode;

const {
  getCreate2Address,
  hexlify,
  hexZeroPad,
  keccak256,
} = require("ethers/lib/utils");
const { EIP4337Lib } = require("soul-wallet-lib/dist/exportLib/EIP4337Lib");
const fs = require("fs");

describe("WalletTest", function () {
  let addr1, addr2, addr3;
  let owner, ownerPrivateKey;
  let entryPoint;
  let smartWalletAddress;
  const chainId = hre.network.config.chainId;

  async function advanceBlockTo(blockNumber) {
    for (let i = await ethers.provider.getBlockNumber(); i < blockNumber; i++) {
      await advanceBlock();
    }
  }

  async function advanceBlock() {
    return ethers.provider.send("evm_mine", []);
  }

  async function create2(from, salt, initCode) {
    const saltBytes32 = hexZeroPad(hexlify(salt), 32);
    const initCodeHash = keccak256(initCode);
    return getCreate2Address(from, saltBytes32, initCodeHash);
  }

  async function deployWallet() {
    SmartWalletImplementation = await ethers.getContractFactory("SmartWallet");
    smartWalletImplementation = await SmartWalletImplementation.deploy();
    let iface = new hre.ethers.utils.Interface(smartWalletAbi);
    const initializationData = iface.encodeFunctionData("initialize", [
      entryPoint.address,
      owner.address,
    ]);
    SmartWallet = await ethers.getContractFactory("WalletProxy");

    let constructorArg = ethers.utils.defaultAbiCoder.encode(
      ["address", "bytes"],
      [smartWalletImplementation.address, initializationData]
    );

    const initCode = `${smartWalletByteCode}${constructorArg.slice(2)}`;

    const salt = 0;
    smartWalletAddress = await create2(create2Factory.address, salt, initCode);
    await entryPoint.connect(addr1).depositTo(smartWalletAddress, {
      value: hre.ethers.utils.parseEther("10").toString(10),
    });

    let userOperation = new EIP4337Lib.UserOperation(
      smartWalletAddress,
      0,
      "0x0000000000000000000000000000000000000000",
      "0x",
      initCode
    );
    userOperation.callGas = 9e6;
    userOperation.verificationGas = 8e6;
    userOperation.preVerificationGas = 7e6;
    userOperation.maxFeePerGas = 10e9;
    userOperation.maxPriorityFeePerGas = 10e9;

    EIP4337Lib.signUserOp(
      userOperation,
      entryPoint.address,
      chainId,
      ownerPrivateKey
    );

    await entryPoint.connect(addr1).handleOps([userOperation], addr1.address);
  }

  before(async function () {
    Create2Factory = await ethers.getContractFactory("Create2Factory");
    create2Factory = await Create2Factory.deploy();
    EntryPoint = await ethers.getContractFactory("EntryPoint");
    entryPoint = await EntryPoint.deploy(
      create2Factory.address,
      hre.ethers.utils.parseEther("1").toString(10),
      10
    );
    await entryPoint.deployed();
    [addr1, addr2, addr3] = await ethers.getSigners();
    let ownerWallet = new ethers.Wallet.createRandom();
    ownerPrivateKey = ownerWallet.privateKey;
    owner = new ethers.Wallet(ownerWallet);
    await deployWallet();
  });

  beforeEach(async function () {});

  describe("wallet test", async function () {
    it("test upgrade", async function () {
      const smartWalletContract = await hre.ethers.getContractAt(
        "SmartWallet",
        smartWalletAddress
      );

      let preUpgradeVersion = await smartWalletContract.getVersion();
      expect(preUpgradeVersion).to.equal(1);

      SmartWalletImplementationV2 = await ethers.getContractFactory(
        "SmartWalletV2Mock"
      );
      smartWalletImplementationV2 = await SmartWalletImplementationV2.deploy();

      let iface = new ethers.utils.Interface([
        `function upgradeTo(address newImplementation)`,
      ]);
      let functionEncode = iface.encodeFunctionData("upgradeTo", [
        smartWalletImplementationV2.address,
      ]);

      let userOperation = new EIP4337Lib.UserOperation(
        smartWalletAddress,
        0,
        "0x0000000000000000000000000000000000000000",
        functionEncode,
        "0x"
      );
      userOperation.callGas = 9e6;
      userOperation.verificationGas = 8e6;
      userOperation.preVerificationGas = 7e6;
      userOperation.maxFeePerGas = 10e9;
      userOperation.maxPriorityFeePerGas = 10e9;

      EIP4337Lib.signUserOp(
        userOperation,
        entryPoint.address,
        chainId,
        ownerPrivateKey
      );

      await entryPoint.connect(addr1).handleOps([userOperation], addr1.address);

      let afterUpgradeVersion = await smartWalletContract.getVersion();
      expect(afterUpgradeVersion).to.equal(2);
    });
  });
});
