import { BigNumber } from "ethers";
import { getCreate2Address, hexlify, hexZeroPad, keccak256 } from "ethers/lib/utils";
import { ethers, network, run } from "hardhat";
import { EIP4337Lib } from 'soul-wallet-lib';
import { USDCoin__factory, USDCPaymaster__factory, Create2Factory__factory, EntryPoint__factory, ERC20__factory } from "../src/types/index";
import { Utils } from "../test/Utils";

function isLocalTestnet() {
  return network.name === "localhost" || network.name === "hardhat"
}

async function main() {
  let mockGasFee =
  {
    "low": {
      "suggestedMaxPriorityFeePerGas": "0",
      "suggestedMaxFeePerGas": "0.1",
      "minWaitTimeEstimate": 15000,
      "maxWaitTimeEstimate": 30000
    },
    "medium": {
      "suggestedMaxPriorityFeePerGas": "0",
      "suggestedMaxFeePerGas": "0.2",
      "minWaitTimeEstimate": 15000,
      "maxWaitTimeEstimate": 45000
    },
    "high": {
      "suggestedMaxPriorityFeePerGas": "0",
      "suggestedMaxFeePerGas": "0.3",
      "minWaitTimeEstimate": 15000,
      "maxWaitTimeEstimate": 60000
    },
    "estimatedBaseFee": "0.1",
    "networkCongestion": 0,
    "latestPriorityFeeRange": [
      "0",
      "0"
    ],
    "historicalPriorityFeeRange": [
      "0",
      "0"
    ],
    "historicalBaseFeeRange": [
      "0.1",
      "0.1"
    ],
    "priorityFeeTrend": "down",
    "baseFeeTrend": "up"
  }

  // npx hardhat run --network goerli scripts/deploy.ts
  // npx hardhat run --network ArbGoerli scripts/deploy.ts

  let create2Factory = '0xce0042B868300000d44A59004Da54A005ffdcf9f';

  let EOA = (await ethers.getSigners())[0];

  // print EOA Address
  console.log("EOA Address:", EOA.address);

  if (isLocalTestnet()) {
    let create2 = await new Create2Factory__factory(EOA).deploy();
    create2Factory = create2.address;
  }

  if (!create2Factory) {
    throw new Error("create2Factory not set");
  }

  const chainId = await (await ethers.provider.getNetwork()).chainId;

  const walletOwner = '0x93EDb58cFc5d77028C138e47Fffb929A57C52082';
  const walletOwnerPrivateKey = '0x82cfe73c005926089ebf7ec1f49852207e5670870d0dfa544caabb83d2cd2d5f';


  const salt = hexZeroPad(hexlify(0), 32);

  // #region Entrypoint 

  const EntryPointFactory = await ethers.getContractFactory("EntryPoint");
  // get EntryPointFactory deployed bytecode
  const EntryPointFactoryBytecode = EntryPointFactory.bytecode;
  // get create2 address
  const EntryPointInitCodeHash = keccak256(EntryPointFactoryBytecode);
  const EntryPointAddress = getCreate2Address(create2Factory, salt, EntryPointInitCodeHash);
  console.log("EntryPointAddress:", EntryPointAddress);
  // if not deployed, deploy
  if (await ethers.provider.getCode(EntryPointAddress) === '0x') {
    console.log("EntryPoint not deployed, deploying...");
    const increaseGasLimit = (estimatedGasLimit: BigNumber) => {
      return ethers.BigNumber.from(Math.pow(10, 7) + '');
      //return estimatedGasLimit.mul(10)  // 10x gas
    }
    const create2FactoryContract = Create2Factory__factory.connect(create2Factory, EOA);
    const estimatedGas = await create2FactoryContract.estimateGas.deploy(EntryPointFactoryBytecode, salt);
    const tx = await create2FactoryContract.deploy(EntryPointFactoryBytecode, salt, { gasLimit: increaseGasLimit(estimatedGas) })
    console.log("EntryPoint tx:", tx.hash);
    while (await ethers.provider.getCode(EntryPointAddress) === '0x') {
      console.log("EntryPoint not deployed, waiting...");
      await new Promise(r => setTimeout(r, 3000));
    }
    if (!isLocalTestnet()) {
      console.log("EntryPoint deployed, verifying...");
      try {
        await run("verify:verify", {
          address: EntryPointAddress,
          constructorArguments: [],
        });
      } catch (error) {
        console.log("EntryPoint verify failed:", error);
      }
    }
  } else {
    console.log("EntryPoint already deployed at:" + EntryPointAddress);
  }

  // #endregion Entrypoint


  // #region WalletLogic 

  const WalletLogicFactory = await ethers.getContractFactory("SmartWallet");
  const WalletLogicBytecode = WalletLogicFactory.bytecode;
  const WalletLogicInitCodeHash = keccak256(WalletLogicBytecode);
  const WalletLogicAddress = getCreate2Address(create2Factory, salt, WalletLogicInitCodeHash);
  console.log("WalletLogicAddress:", WalletLogicAddress);
  // if not deployed, deploy
  if (await ethers.provider.getCode(WalletLogicAddress) === '0x') {
    console.log("WalletLogic not deployed, deploying...");
    const increaseGasLimit = (estimatedGasLimit: BigNumber) => {
      return ethers.BigNumber.from(Math.pow(10, 7) + '');
      //return estimatedGasLimit.mul(10)  // 10x gas
    }
    const create2FactoryContract = Create2Factory__factory.connect(create2Factory, EOA);
    const estimatedGas = await create2FactoryContract.estimateGas.deploy(WalletLogicBytecode, salt);
    const tx = await create2FactoryContract.deploy(WalletLogicBytecode, salt, { gasLimit: increaseGasLimit(estimatedGas) })
    console.log("WalletLogic tx:", tx.hash);
    while (await ethers.provider.getCode(WalletLogicAddress) === '0x') {
      console.log("WalletLogic not deployed, waiting...");
      await new Promise(r => setTimeout(r, 3000));
    }

    if (!isLocalTestnet()) {
      console.log("WalletLogic deployed, verifying...");
      try {
        await run("verify:verify", {
          address: WalletLogicAddress,
          constructorArguments: [],
        });
      } catch (error) {
        console.log("WalletLogic verify failed:", error);
      }
    }
  } else {
  }

  // #endregion WalletLogic


  // #region GuardianLogic 

  const GuardianLogicFactory = await ethers.getContractFactory("GuardianMultiSigWallet");
  const GuardianLogicBytecode = GuardianLogicFactory.bytecode;
  const GuardianLogicInitCodeHash = keccak256(GuardianLogicBytecode);
  const GuardianLogicAddress = getCreate2Address(create2Factory, salt, GuardianLogicInitCodeHash);
  console.log("GuardianLogicAddress:", GuardianLogicAddress);
  // if not deployed, deploy
  if (await ethers.provider.getCode(GuardianLogicAddress) === '0x') {
    console.log("GuardianLogic not deployed, deploying...");
    const increaseGasLimit = (estimatedGasLimit: BigNumber) => {
      return ethers.BigNumber.from(Math.pow(10, 7) + '');
      //return estimatedGasLimit.mul(10)  // 10x gas
    }
    const create2FactoryContract = Create2Factory__factory.connect(create2Factory, EOA);
    const estimatedGas = await create2FactoryContract.estimateGas.deploy(GuardianLogicBytecode, salt);
    const tx = await create2FactoryContract.deploy(GuardianLogicBytecode, salt, { gasLimit: increaseGasLimit(estimatedGas) })
    console.log("GuardianLogic tx:", tx.hash);
    while (await ethers.provider.getCode(GuardianLogicAddress) === '0x') {
      console.log("GuardianLogic not deployed, waiting...");
      await new Promise(r => setTimeout(r, 3000));
    }
    if (!isLocalTestnet()) {
      console.log("GuardianLogic deployed, verifying...");
      try {
        await run("verify:verify", {
          address: GuardianLogicAddress,
          constructorArguments: [],
        });
      } catch (error) {
        console.log("GuardianLogic verify failed:", error);
      }
    }
  } else {
  }

  // #endregion GuardianLogic

  // #region deploy wallet
  const guardiansAddress = ['0x0000000000000000000000000000000000000001', '0x0000000000000000000000000000000000000002', '0x0000000000000000000000000000000000000003'];
  const guardianCreateSalt = Math.random().toString();
  const gurdianAddressAndInitCode = EIP4337Lib.Guardian.calculateGuardianAndInitCode(
    GuardianLogicAddress,
    guardiansAddress,
    Math.floor(guardiansAddress.length / 2),
    guardianCreateSalt,
    create2Factory);

  console.log('gurdianAddress: ' + gurdianAddressAndInitCode.address);

  const upgradeDelay = 10;
  const guardianDelay = 10;
  const walletAddress = await EIP4337Lib.calculateWalletAddress(
    WalletLogicAddress,
    EntryPointAddress,
    walletOwner,
    upgradeDelay,
    guardianDelay,
    gurdianAddressAndInitCode.address,
    0,
    create2Factory
  );

  console.log('walletAddress: ' + walletAddress);


  // check if wallet is activated (deployed) 
  const code = await ethers.provider.getCode(walletAddress);
  if (code === "0x") {
    // get gas price
    let eip1559GasFee: any;
    if (!isLocalTestnet()) {
      if (network.name === 'ArbGoerli') {
        eip1559GasFee = mockGasFee;
      } else {
        eip1559GasFee =
          await EIP4337Lib.Utils.suggestedGasFee.getEIP1559GasFees(chainId);
      }
      if (!eip1559GasFee) {
        throw new Error("eip1559GasFee is null");
      }
    } else {
      eip1559GasFee = mockGasFee;
    }

    // send 0.0005 ETH to wallet address
    const tx = await EOA.sendTransaction({
      to: walletAddress,
      value: ethers.utils.parseEther("0.0005")
    });
    await tx.wait();
    // check wallet balance
    const balance = await ethers.provider.getBalance(walletAddress);
    console.log("wallet balance:", ethers.utils.formatEther(balance));

    const activateOp = EIP4337Lib.activateWalletOp(
      WalletLogicAddress,
      EntryPointAddress,
      walletOwner,
      upgradeDelay,
      guardianDelay,
      gurdianAddressAndInitCode.address,
      EIP4337Lib.Defines.AddressZero,
      0,
      create2Factory,
      ethers.utils
        .parseUnits(eip1559GasFee.medium.suggestedMaxFeePerGas, "gwei")
        .toString(),
      ethers.utils
        .parseUnits(
          eip1559GasFee.medium.suggestedMaxPriorityFeePerGas,
          "gwei"
        )
        .toString()
    );

    const userOpHash = activateOp.getUserOpHash(EntryPointAddress, chainId);

    activateOp.signWithSignature(
      walletOwner,
      Utils.signMessage(userOpHash, walletOwnerPrivateKey)
    );
    await EIP4337Lib.RPC.simulateHandleOp(
      ethers.provider,
      EntryPointAddress,
      activateOp
    );
    const EntryPoint = EntryPoint__factory.connect(EntryPointAddress, EOA);
    const re = await EntryPoint.handleOps([activateOp], EOA.address,{
      maxFeePerGas: ethers.utils.parseUnits(eip1559GasFee.medium.suggestedMaxFeePerGas, "gwei"),
      maxPriorityFeePerGas: ethers.utils.parseUnits(eip1559GasFee.medium.suggestedMaxPriorityFeePerGas, "gwei")
    });
    console.log(re);
  }



  // #endregion deploy wallet

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});