/*
 * @Description: 
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-12-26 23:06:27
 * @LastEditors: cejay
 * @LastEditTime: 2023-02-13 17:02:33
 */

import { BigNumber } from "ethers";
import { getCreate2Address, hexlify, hexZeroPad, keccak256 } from "ethers/lib/utils";
import { ethers, network, run } from "hardhat";
import { IUserOpReceipt, SoulWalletLib, UserOperation } from 'soul-wallet-lib';
import { USDCoin__factory, TokenPaymaster__factory, Create2Factory__factory, EntryPoint__factory, ERC20__factory } from "../src/types/index";
import { Utils } from "../test/Utils";

function isLocalTestnet() {
  return ['localhost', 'hardhat'].includes(network.name);
}

async function main() {

  let mockGasFee = {
    "low": {
      "suggestedMaxPriorityFeePerGas": "0.1",
      "suggestedMaxFeePerGas": "10"
    },
    "medium": {
      "suggestedMaxPriorityFeePerGas": "0.1",
      "suggestedMaxFeePerGas": "11"
    },
    "high": {
      "suggestedMaxPriorityFeePerGas": "0.1",
      "suggestedMaxFeePerGas": "12"
    },
    "estimatedBaseFee": "1",
    "networkCongestion": 0.31675,
    "latestPriorityFeeRange": [
      "0.131281956",
      "4.015436404"
    ],
    "historicalPriorityFeeRange": [
      "0.02829803",
      "58.45567467"
    ],
    "historicalBaseFeeRange": [
      "13.492240252",
      "17.51875421"
    ],
    "priorityFeeTrend": "level",
    "baseFeeTrend": "down"
  }

  // npx hardhat run --network hardhat scripts/deploy.ts
  // npx hardhat run --network ArbGoerli scripts/deploy.ts


  let EOA = (await ethers.getSigners())[0];

  // print EOA Address
  console.log("EOA Address:", EOA.address);


  let USDCContractAddress = '';
  let USDCPriceFeedAddress = '';

  let eip1559GasFee;

  let soulWalletLib;

  const networkBundler: Map<string, string> = new Map();
  networkBundler.set('ArbGoerli', 'https://bundler-arb-goerli.soulwallets.me/rpc');



  if (isLocalTestnet()) {
    let create2 = await new Create2Factory__factory(EOA).deploy();
    soulWalletLib = new SoulWalletLib(create2.address);
    let usdc = await new USDCoin__factory(EOA).deploy();
    USDCContractAddress = usdc.address;
    USDCPriceFeedAddress = await (await (await ethers.getContractFactory("USDCPriceFeed")).deploy()).address;
    eip1559GasFee = mockGasFee;
  } else {
    soulWalletLib = new SoulWalletLib();
    // if (["mainnet", "goerli"].includes(network.name)) {
    //   USDCContractAddress = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
    //  eip1559GasFee = await EIP4337Lib.Utils.suggestedGasFee.getEIP1559GasFees(chainId);
    // } else 
    if (network.name === "ArbGoerli") {
      USDCContractAddress = "0xe34a90dF83c29c28309f58773C41122d4E8C757A";
      //https://docs.chain.link/data-feeds/price-feeds/addresses/?network=arbitrum
      USDCPriceFeedAddress = "0x62CAe0FA2da220f43a51F86Db2EDb36DcA9A5A08";
      eip1559GasFee = mockGasFee;
    } else {
      throw new Error("network not support");
    }
  }
  // get code of soulWalletLib.singletonFactory
  if (await ethers.provider.getCode(soulWalletLib.singletonFactory) === '0x') {
    throw new Error("singletonFactory not deployed");
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
  const EntryPointAddress = getCreate2Address(soulWalletLib.singletonFactory, salt, EntryPointInitCodeHash);
  console.log("EntryPointAddress:", EntryPointAddress);
  // if not deployed, deploy
  if (await ethers.provider.getCode(EntryPointAddress) === '0x') {
    console.log("EntryPoint not deployed, deploying...");
    const increaseGasLimit = (estimatedGasLimit: BigNumber) => {
      return ethers.BigNumber.from(Math.pow(10, 7) + '');
      //return estimatedGasLimit.mul(10)  // 10x gas
    }
    const create2FactoryContract = Create2Factory__factory.connect(soulWalletLib.singletonFactory, EOA);
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
  const WalletLogicAddress = getCreate2Address(soulWalletLib.singletonFactory, salt, WalletLogicInitCodeHash);
  console.log("WalletLogicAddress:", WalletLogicAddress);
  // if not deployed, deploy
  if (await ethers.provider.getCode(WalletLogicAddress) === '0x') {
    console.log("WalletLogic not deployed, deploying...");
    const increaseGasLimit = (estimatedGasLimit: BigNumber) => {
      return ethers.BigNumber.from(Math.pow(10, 7) + '');
      //return estimatedGasLimit.mul(10)  // 10x gas
    }
    const create2FactoryContract = Create2Factory__factory.connect(soulWalletLib.singletonFactory, EOA);
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

  // #region WalletFactory

  const walletFactoryAddress = soulWalletLib.Utils.deployFactory.getAddress(WalletLogicAddress);
  console.log("walletFactoryAddress:", walletFactoryAddress);
  // if not deployed, deploy
  if (await ethers.provider.getCode(walletFactoryAddress) === '0x') {
    console.log("walletFactory not deployed, deploying...");
    const increaseGasLimit = (estimatedGasLimit: BigNumber) => {
      return ethers.BigNumber.from(Math.pow(10, 7) + '');
      //return estimatedGasLimit.mul(10)  // 10x gas
    }
    await soulWalletLib.Utils.deployFactory.deploy(WalletLogicAddress, ethers.provider, EOA);

    while (await ethers.provider.getCode(walletFactoryAddress) === '0x') {
      console.log("walletFactory not deployed, waiting...");
      await new Promise(r => setTimeout(r, 3000));
    }

    if (!isLocalTestnet()) {
      console.log("walletFactory deployed, verifying...");
      try {
        // verify contract/SmartWalletFactory.sol:SmartWalletFactory at walletFactoryAddress
        {
          // npx hardhat verify --network ArbGoerli 0xb8EE53678Ffc1fcc1Bec87dEF082dB4Afc72c92B 0xaD1021AD721cb98E682F51489b1aD84395F3e495 0xce0042B868300000d44A59004Da54A005ffdcf9f 
          console.log("walletFactoryAddress:", walletFactoryAddress);
          console.log("WalletLogicAddress:", WalletLogicAddress);
          console.log("soulWalletLib.singletonFactory:", soulWalletLib.singletonFactory);
        }
        await run("verify:verify", {
          address: walletFactoryAddress,
          constructorArguments: [
            WalletLogicAddress,
            soulWalletLib.singletonFactory
          ]
        });
      } catch (error) {
        console.log("walletFactory verify failed:", error);
      }
    }
  } else {
  }

  const WalletFactory = {
    contract: await ethers.getContractAt("SmartWalletFactory", walletFactoryAddress)
  };


  // #endregion WalletFactory



  // #region TokenPaymaster 

  const TokenPaymasterFactory = await ethers.getContractFactory("TokenPaymaster");
  //constructor(IEntryPoint _entryPoint, address _owner, address _walletFactory)
  const TokenPaymasterBytecode = TokenPaymasterFactory.getDeployTransaction(EntryPointAddress, EOA.address, WalletFactory.contract.address).data;
  if (!TokenPaymasterBytecode) {
    throw new Error("TokenPaymasterBytecode not set");
  }
  const TokenPaymasterInitCodeHash = keccak256(TokenPaymasterBytecode);
  const TokenPaymasterAddress = getCreate2Address(soulWalletLib.singletonFactory, salt, TokenPaymasterInitCodeHash);
  console.log("TokenPaymasterAddress:", TokenPaymasterAddress);
  // if not deployed, deploy
  if (await ethers.provider.getCode(TokenPaymasterAddress) === '0x') {
    console.log("TokenPaymaster not deployed, deploying...");
    const increaseGasLimit = (estimatedGasLimit: BigNumber) => {
      return ethers.BigNumber.from(Math.pow(10, 7) + '');
      //return estimatedGasLimit.mul(10)  // 10x gas
    }
    const create2FactoryContract = Create2Factory__factory.connect(soulWalletLib.singletonFactory, EOA);
    const estimatedGas = await create2FactoryContract.estimateGas.deploy(TokenPaymasterBytecode, salt);
    const tx = await create2FactoryContract.deploy(TokenPaymasterBytecode, salt, { gasLimit: increaseGasLimit(estimatedGas) })
    console.log("EntryPoint tx:", tx.hash);
    while (await ethers.provider.getCode(TokenPaymasterAddress) === '0x') {
      console.log("TokenPaymaster not deployed, waiting...");
      await new Promise(r => setTimeout(r, 3000));
    }
    {
      const _paymasterStake = '' + Math.pow(10, 17);
      const TokenPaymaster = await TokenPaymaster__factory.connect(TokenPaymasterAddress, EOA);
      console.log(await TokenPaymaster.owner());

      await TokenPaymaster.setToken([USDCContractAddress], [USDCPriceFeedAddress]);

      console.log('adding stake');
      await TokenPaymaster.addStake(
        1, {
        from: EOA.address,
        value: _paymasterStake
      });
      await TokenPaymaster.deposit({
        from: EOA.address,
        value: _paymasterStake
      });
    }

    if (!isLocalTestnet()) {
      console.log("TokenPaymaster deployed, verifying...");
      try {
        await run("verify:verify", {
          address: TokenPaymasterAddress,
          constructorArguments: [
            EntryPointAddress, EOA.address, WalletFactory.contract.address
          ],
        });
      } catch (error) {
        console.log("TokenPaymaster verify failed:", error);
      }
    }
  } else {

  }


  // #endregion TokenPaymaster

  // #region GuardianLogic 

  const GuardianLogicFactory = await ethers.getContractFactory("GuardianMultiSigWallet");
  const GuardianLogicBytecode = GuardianLogicFactory.bytecode;
  const GuardianLogicInitCodeHash = keccak256(GuardianLogicBytecode);
  const GuardianLogicAddress = getCreate2Address(soulWalletLib.singletonFactory, salt, GuardianLogicInitCodeHash);
  console.log("GuardianLogicAddress:", GuardianLogicAddress);
  // if not deployed, deploy
  if (await ethers.provider.getCode(GuardianLogicAddress) === '0x') {
    console.log("GuardianLogic not deployed, deploying...");
    const increaseGasLimit = (estimatedGasLimit: BigNumber) => {
      return ethers.BigNumber.from(Math.pow(10, 7) + '');
      //return estimatedGasLimit.mul(10)  // 10x gas
    }
    const create2FactoryContract = Create2Factory__factory.connect(soulWalletLib.singletonFactory, EOA);
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
  if (true) {

    const upgradeDelay = 10;
    const guardianDelay = 10;

    const walletAddress = await soulWalletLib.calculateWalletAddress(
      WalletLogicAddress,
      EntryPointAddress,
      walletOwner,
      upgradeDelay,
      guardianDelay,
      SoulWalletLib.Defines.AddressZero
    );

    console.log('walletAddress: ' + walletAddress);

    // check if wallet is activated (deployed) 
    const code = await ethers.provider.getCode(walletAddress);
    if (code === "0x") {

      const activateOp = soulWalletLib.activateWalletOp(
        WalletLogicAddress,
        EntryPointAddress,
        walletOwner,
        upgradeDelay,
        guardianDelay,
        SoulWalletLib.Defines.AddressZero,
        '0x',
        ethers.utils
          .parseUnits(eip1559GasFee.high.suggestedMaxFeePerGas, "gwei")
          .toString(),
        ethers.utils
          .parseUnits(eip1559GasFee.high.suggestedMaxPriorityFeePerGas, "gwei")
          .toString()
      );

      const requiredPrefund = activateOp.requiredPrefund(ethers.utils.parseUnits(eip1559GasFee.estimatedBaseFee, "gwei"));
      console.log('requiredPrefund: ' + ethers.utils.formatEther(requiredPrefund) + ' ETH');
      // send `requiredPrefund` ETH to wallet
      const _balance = await ethers.provider.getBalance(walletAddress);
      if (_balance.lt(requiredPrefund)) {
        const _requiredfund = requiredPrefund.sub(_balance);
        console.log('sending ' + ethers.utils.formatEther(_requiredfund) + ' ETH to wallet');
        await EOA.sendTransaction({
          to: walletAddress,
          value: _requiredfund,
          from: EOA.address
        });
      }

      const userOpHash = activateOp.getUserOpHash(EntryPointAddress, chainId);
      activateOp.signWithSignature(
        walletOwner,
        Utils.signMessage(userOpHash, walletOwnerPrivateKey)
      );
      const bundler = new soulWalletLib.Bundler(EntryPointAddress, ethers.provider, '');
      //await bundler.init(); // run init to check bundler is alivable
      const validation = await bundler.simulateValidation(activateOp);
      if (validation.status !== 0) {
        throw new Error(`error code:${validation.status}`);
      }
      const simulate = await bundler.simulateHandleOp(activateOp);
      if (simulate.status !== 0) {
        throw new Error(`error code:${simulate.status}`);
      }

      if (true) {
        const EntryPoint = EntryPoint__factory.connect(EntryPointAddress, EOA);
        const re = await EntryPoint.handleOps([activateOp], EOA.address);
        console.log(re);
        // check if wallet is activated (deployed)
        const code = await ethers.provider.getCode(walletAddress);
        if (code === "0x") {
          throw new Error("wallet not activated");
        } else {
          console.log("wallet activated");
        }
      }

    } else {
      // bundler test
      const nonce = await soulWalletLib.Utils.getNonce(walletAddress, ethers.provider);
      let sendETHOP = await soulWalletLib.Tokens.ETH.transfer(
        ethers.provider,
        walletAddress,
        nonce,
        EntryPointAddress,
        SoulWalletLib.Defines.AddressZero,
        ethers.utils.parseUnits(eip1559GasFee.medium.suggestedMaxFeePerGas, 'gwei').toString(),
        ethers.utils.parseUnits(eip1559GasFee.medium.suggestedMaxPriorityFeePerGas, 'gwei').mul(3).toString(),
        EOA.address,
        '2'
      );
      if (!sendETHOP) {
        throw new Error("sendETHOP is null");
      }


      const requiredPrefund = sendETHOP.requiredPrefund(ethers.utils.parseUnits(eip1559GasFee.estimatedBaseFee, "gwei"));
      console.log('requiredPrefund: ' + ethers.utils.formatEther(requiredPrefund) + ' ETH');
      // send `requiredPrefund` ETH to wallet
      const _balance = await ethers.provider.getBalance(walletAddress);
      if (_balance.lt(requiredPrefund)) {
        const _requiredfund = requiredPrefund.sub(_balance);
        console.log('sending ' + ethers.utils.formatEther(_requiredfund) + ' ETH to wallet');
        await EOA.sendTransaction({
          to: walletAddress,
          value: _requiredfund,
          from: EOA.address
        });
      }

      const userOpHash = sendETHOP.getUserOpHash(EntryPointAddress, chainId);

      sendETHOP.signWithSignature(
        walletOwner,
        Utils.signMessage(userOpHash, walletOwnerPrivateKey)
      );

      const bundlerUrl = networkBundler.get(network.name);
      if (!bundlerUrl) {
        throw new Error(`bundler rpc not found for network ${network.name}`);
      }
      const bundler = new soulWalletLib.Bundler(EntryPointAddress, ethers.provider, bundlerUrl);
      await bundler.init();

      const validation = await bundler.simulateValidation(sendETHOP);
      if (validation.status !== 0) {
        throw new Error(`error code:${validation.status}`);
      }
      const simulate = await bundler.simulateHandleOp(sendETHOP);
      if (simulate.status !== 0) {
        throw new Error(`error code:${simulate.status}`);
      }

      const receipt: IUserOpReceipt | null = await bundler.eth_getUserOperationReceipt('0xf54c61c780e9c0324147e3f6214d8a007051c90df035a20891bcdb807d4ef71e');

      const bundlerEvent = bundler.sendUserOperation(sendETHOP, 1000 * 60 * 3);
      bundlerEvent.on('error', (err: any) => {
        console.log(err);
      });
      bundlerEvent.on('send', (userOpHash: string) => {
        console.log('send: ' + userOpHash);
      });
      bundlerEvent.on('receipt', (receipt: IUserOpReceipt) => {
        console.log('receipt: ' + receipt);
      });
      bundlerEvent.on('timeout', () => {
        console.log('timeout');
      });
      while(true){
        await new Promise((resolve) => setTimeout(resolve, 1000));
      }
    }


  }


  // #endregion deploy wallet


}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});