/*
 * @Description: 
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-12-26 23:06:27
 * @LastEditors: cejay
 * @LastEditTime: 2023-03-12 22:54:24
 */
import { BigNumber } from "ethers";
import { getCreate2Address, hexlify, hexZeroPad, keccak256 } from "ethers/lib/utils";
import { ethers, network, run } from "hardhat";
import { Bundler, IUserOpReceipt, SoulWalletLib, UserOperation } from 'soul-wallet-lib';
import { toNumber } from "soul-wallet-lib/dist/defines/numberLike";
import { USDCoin__factory, TokenPaymaster__factory, SingletonFactory__factory, SoulWalletFactory__factory, SoulWallet__factory, EstimateGasHelper__factory } from "../src/types/index";
import { Utils } from "../test/Utils";

function isLocalTestnet() {
  return ['localhost', 'hardhat'].includes(network.name);
}

/**
 * run activateWallet test
 */
let activateWalletTest = true;

/**
 * run recoverWallet test
 */
let recoverWalletTest = false;

/**
 * run activateWalletWithPaymaster test
 */
let activateWalletWithPaymasterTest = true;


async function estimateUserOperationGas(bundler: Bundler, userOp: UserOperation) {
  const estimateData = await bundler.eth_estimateUserOperationGas(userOp);
  if (toNumber(userOp.callGasLimit) === 0) {
    userOp.callGasLimit = estimateData.callGasLimit;
  }
  userOp.preVerificationGas = estimateData.preVerificationGas;
  userOp.verificationGasLimit = estimateData.verificationGas;
}



async function main() {

  console.log("network.name:", network.name);

  // #region mock gas fee

  let mockGasFee = {
    "low": {
      "suggestedMaxPriorityFeePerGas": "0.1",
      "suggestedMaxFeePerGas": "12"
    },
    "medium": {
      "suggestedMaxPriorityFeePerGas": "0.1",
      "suggestedMaxFeePerGas": "13"
    },
    "high": {
      "suggestedMaxPriorityFeePerGas": "0.1",
      "suggestedMaxFeePerGas": "14"
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

  // #endregion mock gas fee

  // #region prepare

  let EOA = (await ethers.getSigners())[0];

  let USDCContractAddresses: string[] = [];
  let USDCPriceFeedAddress = '';

  let eip1559GasFee;

  let soulWalletLib;

  const networkBundler: Map<string, string> = new Map();
  networkBundler.set('goerli', 'https://bundler-eth-goerli.soulwallets.me/rpc');
  networkBundler.set('arbitrumGoerli', 'https://bundler-arb-goerli.soulwallets.me/rpc');
  networkBundler.set('optimisticGoerli', 'https://bundler-op-goerli.soulwallets.me/rpc');
  networkBundler.set('arbitrum', 'https://bundler-arb-main.soulwallets.me/rpc');


  const chainId = await (await ethers.provider.getNetwork()).chainId;


  // create EOA account
  const bundlerEOA = await ethers.Wallet.createRandom();

  if (isLocalTestnet()) {
    let create2 = await new SingletonFactory__factory(EOA).deploy();
    soulWalletLib = new SoulWalletLib(create2.address);
    let usdc = await new USDCoin__factory(EOA).deploy();
    USDCContractAddresses = [usdc.address];
    USDCPriceFeedAddress = await (await (await ethers.getContractFactory("MockOracle")).deploy()).address;
    eip1559GasFee = mockGasFee;
    await EOA.sendTransaction({ to: bundlerEOA.address, value: ethers.utils.parseEther("10") });

  } else {
    soulWalletLib = new SoulWalletLib();
    if (network.name === "arbitrum") {

      USDCContractAddresses = [
        '0x8Da746c5641a8720b641685E3679F4B7f294df2C', // USD Mock Coin
        '0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1', // DAI
        '0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8', // USDC
        '0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9', // USDT
      ];
      //https://docs.chain.link/data-feeds/price-feeds/addresses/?network=arbitrum
      USDCPriceFeedAddress = "0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612";

      eip1559GasFee = await soulWalletLib.Utils.suggestedGasFee.getEIP1559GasFees(chainId);
      if (!eip1559GasFee) {
        throw new Error("getEIP1559GasFees failed");
      }

    } else if (network.name === "arbitrumGoerli") {

      USDCContractAddresses = ["0xe34a90dF83c29c28309f58773C41122d4E8C757A"];
      //https://docs.chain.link/data-feeds/price-feeds/addresses/?network=arbitrum
      USDCPriceFeedAddress = "0x62CAe0FA2da220f43a51F86Db2EDb36DcA9A5A08";

      eip1559GasFee = mockGasFee;
      //  Max Fee per Gas 1.62 Gwei
      //  Gas Price 0.1 Gwei
      eip1559GasFee.high.suggestedMaxFeePerGas = "1.62";
      eip1559GasFee.high.suggestedMaxPriorityFeePerGas = "0.1";

    } else if (network.name === "goerli") {

      USDCContractAddresses = ["0x55dFb37E7409c4e2B114f8893E67D4Ff32783b35"];

      //https://docs.chain.link/data-feeds/price-feeds/addresses/?network=ethereum
      USDCPriceFeedAddress = "0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e";

      eip1559GasFee = await soulWalletLib.Utils.suggestedGasFee.getEIP1559GasFees(chainId);
      if (!eip1559GasFee) {
        throw new Error("getEIP1559GasFees failed");
      }

    } else if (network.name === 'optimisticGoerli') {

      USDCContractAddresses = ["0x7627e9FA4C4FfaeFb144c81a6892B2c33cfF3c88"];

      https://docs.chain.link/data-feeds/price-feeds/addresses/?network=optimism
      USDCPriceFeedAddress = "0x57241A37733983F97C4Ab06448F244A1E0Ca0ba8";

      eip1559GasFee = mockGasFee;
      const gasPrice = (await ethers.provider.getGasPrice()).mul(150).div(100).toString();
      const gasPriceGwei = ethers.utils.formatUnits(gasPrice, 'gwei');

      eip1559GasFee.high.suggestedMaxFeePerGas = gasPriceGwei;
      eip1559GasFee.high.suggestedMaxPriorityFeePerGas = gasPriceGwei;

    } else if (network.name === 'optimistic') {

      USDCContractAddresses = [
        '0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1', // DAI
        '0x94b008aA00579c1307B0EF2c499aD98a8ce58e58', // USDT
        '0x7F5c764cBc14f9669B88837ca1490cCa17c31607'  // USDC
      ];

      https://docs.chain.link/data-feeds/price-feeds/addresses/?network=optimism
      USDCPriceFeedAddress = "0x13e3Ee699D1909E989722E753853AE30b17e08c5";

      eip1559GasFee = mockGasFee;

      const legacyGasPrice = await soulWalletLib.Utils.suggestedGasFee.getLegacyGasPrices(chainId);
      if (!legacyGasPrice) {
        throw new Error("getLegacyGasPrices failed");
      }
      eip1559GasFee.high.suggestedMaxFeePerGas = legacyGasPrice.ProposeGasPrice;
      eip1559GasFee.high.suggestedMaxPriorityFeePerGas = legacyGasPrice.ProposeGasPrice;

    }
    else {
      throw new Error("network not support");
    }
  }
  // get code of soulWalletLib.singletonFactory
  if (await ethers.provider.getCode(soulWalletLib.singletonFactory) === '0x') {
    throw new Error("singletonFactory not deployed");
  }


  const walletOwner = '0x93EDb58cFc5d77028C138e47Fffb929A57C52082';
  const walletOwnerPrivateKey = '0x82cfe73c005926089ebf7ec1f49852207e5670870d0dfa544caabb83d2cd2d5f';


  const salt = hexZeroPad(hexlify(0), 32);

  // #endregion prepare

  // #region Entrypoint 
  let EntryPointAddress = '0x0576a174D229E3cFA37253523E645A78A0C91B57';
  if (await ethers.provider.getCode(EntryPointAddress) === '0x') {
    if (!isLocalTestnet()) {
      debugger;
    }
    const EntryPointFactory = await ethers.getContractFactory("EntryPoint");
    // get EntryPointFactory deployed bytecode
    const EntryPointFactoryBytecode = EntryPointFactory.bytecode;
    // get create2 address
    const EntryPointInitCodeHash = keccak256(EntryPointFactoryBytecode);
    EntryPointAddress = getCreate2Address(soulWalletLib.singletonFactory, salt, EntryPointInitCodeHash);
    console.log("EntryPointAddress:", EntryPointAddress);
    // if not deployed, deploy
    if (await ethers.provider.getCode(EntryPointAddress) === '0x') {
      console.log("EntryPoint not deployed, deploying...");
      const increaseGasLimit = (estimatedGasLimit: BigNumber) => {

        let gasLimit = BigNumber.from(7000000);
        if (network.name === 'arbitrum' || network.name === 'arbitrumGoerli') {
          gasLimit = gasLimit.mul(40);
        }
        return gasLimit;
        //return estimatedGasLimit.mul(10)
      }
      const create2FactoryContract = SingletonFactory__factory.connect(soulWalletLib.singletonFactory, EOA);
      const estimatedGas = await create2FactoryContract.estimateGas.deploy(EntryPointFactoryBytecode, salt);
      const tx = await create2FactoryContract.deploy(EntryPointFactoryBytecode, salt, { gasLimit: increaseGasLimit(estimatedGas) })
      console.log("EntryPoint tx:", tx.hash);
      while (await ethers.provider.getCode(EntryPointAddress) === '0x') {
        console.log("EntryPoint not deployed, waiting...");
        await new Promise(r => setTimeout(r, 3000));
      }
      if (!isLocalTestnet()) {
        console.log("EntryPoint deployed, verifying...");
        await new Promise(r => setTimeout(r, 5000));
        if (!isLocalTestnet()) {
          debugger;
        }
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
  }
  // #endregion Entrypoint

  // #region EstimateGasHelper
  let EstimateGasHelperAddress: string | undefined = undefined;
  if (network.name === 'arbitrum' || network.name === 'arbitrumGoerli') {
    const EstimateGasHelperFactory = await ethers.getContractFactory("EstimateGasHelper");
    const EstimateGasHelperBytecode = EstimateGasHelperFactory.bytecode;
    const EstimateGasHelperInitCodeHash = keccak256(EstimateGasHelperBytecode);
    EstimateGasHelperAddress = getCreate2Address(soulWalletLib.singletonFactory, salt, EstimateGasHelperInitCodeHash);
    console.log("EstimateGasHelperAddress:", EstimateGasHelperAddress);
    // if not deployed, deploy
    if (await ethers.provider.getCode(EstimateGasHelperAddress) === '0x') {
      debugger;
      console.log("EstimateGasHelper not deployed, deploying...");
      const increaseGasLimit = (estimatedGasLimit: BigNumber) => {
        let gasLimit = BigNumber.from(1000000);
        if (network.name === 'arbitrum' || network.name === 'arbitrumGoerli') {
          gasLimit = gasLimit.mul(40);
        }
        return gasLimit;
        //return estimatedGasLimit.mul(10)
      }
      const create2FactoryContract = SingletonFactory__factory.connect(soulWalletLib.singletonFactory, EOA);
      const estimatedGas = await create2FactoryContract.estimateGas.deploy(EstimateGasHelperBytecode, salt);
      const tx = await create2FactoryContract.deploy(EstimateGasHelperBytecode, salt, { gasLimit: increaseGasLimit(estimatedGas) })
      console.log("EstimateGasHelper tx:", tx.hash);
      while (await ethers.provider.getCode(EstimateGasHelperAddress) === '0x') {
        console.log("EstimateGasHelper not deployed, waiting...");
        await new Promise(r => setTimeout(r, 3000));
      }
      console.log("EstimateGasHelper deployed at:" + EstimateGasHelperAddress);
    } else {
      console.log("EstimateGasHelper already deployed at:" + EstimateGasHelperAddress);
    }
  }

  // #endregion EstimateGasHelper

  // #region WalletLogic 

  const WalletLogicFactory = await ethers.getContractFactory("SoulWallet");
  const WalletLogicBytecode = WalletLogicFactory.bytecode;
  const WalletLogicInitCodeHash = keccak256(WalletLogicBytecode);
  const WalletLogicAddress = getCreate2Address(soulWalletLib.singletonFactory, salt, WalletLogicInitCodeHash);
  console.log("WalletLogicAddress:", WalletLogicAddress);
  // if not deployed, deploy
  if (await ethers.provider.getCode(WalletLogicAddress) === '0x') {
    debugger;
    console.log("WalletLogic not deployed, deploying...");
    const increaseGasLimit = (estimatedGasLimit: BigNumber) => {
      let gasLimit = BigNumber.from(7000000);
      if (network.name === 'arbitrum' || network.name === 'arbitrumGoerli') {
        gasLimit = gasLimit.mul(40);
      }
      return gasLimit;
      //return estimatedGasLimit.mul(10)
    }
    const create2FactoryContract = SingletonFactory__factory.connect(soulWalletLib.singletonFactory, EOA);
    const estimatedGas = await create2FactoryContract.estimateGas.deploy(WalletLogicBytecode, salt);
    const tx = await create2FactoryContract.deploy(WalletLogicBytecode, salt, { gasLimit: increaseGasLimit(estimatedGas) })
    console.log("WalletLogic tx:", tx.hash);
    while (await ethers.provider.getCode(WalletLogicAddress) === '0x') {
      console.log("WalletLogic not deployed, waiting...");
      await new Promise(r => setTimeout(r, 3000));
    }

    if (!isLocalTestnet()) {
      console.log("WalletLogic deployed, verifying...");
      await new Promise(r => setTimeout(r, 5000));
      if (!isLocalTestnet()) {
        debugger;
      }
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
    console.log("WalletLogic already deployed at:" + WalletLogicAddress);
  }
  // #endregion WalletLogic

  // #region WalletFactory

  const walletFactoryAddress = soulWalletLib.Utils.deployFactory.getAddress(WalletLogicAddress, undefined, undefined, {
    contractInterface: SoulWalletFactory__factory.abi,
    bytecode: SoulWalletFactory__factory.bytecode
  });
  console.log("walletFactoryAddress:", walletFactoryAddress);
  // if not deployed, deploy
  if (await ethers.provider.getCode(walletFactoryAddress) === '0x') {
    debugger;
    console.log("walletFactory not deployed, deploying...");
    let gasLimit = BigNumber.from(6000000);
    if (network.name === 'arbitrum' || network.name === 'arbitrumGoerli') {
      gasLimit = gasLimit.mul(40);
    }
    const walletFactoryAddress_online = await soulWalletLib.Utils.deployFactory.deploy(WalletLogicAddress, ethers.provider, EOA, undefined, undefined, undefined, gasLimit);
    if (walletFactoryAddress_online !== walletFactoryAddress) {
      throw new Error("walletFactoryAddress_online not match");
    }

    while (await ethers.provider.getCode(walletFactoryAddress) === '0x') {
      console.log("walletFactory not deployed, waiting...");
      await new Promise(r => setTimeout(r, 3000));
    }

    if (!isLocalTestnet()) {
      console.log("walletFactory deployed, verifying...");
      await new Promise(r => setTimeout(r, 5000));
      if (!isLocalTestnet()) {
        debugger;
      }
      try {
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
    console.log("walletFactory already deployed at:" + walletFactoryAddress);
  }

  const WalletFactory = {
    contract: await ethers.getContractAt("SoulWalletFactory", walletFactoryAddress)
  };


  // #endregion WalletFactory

  // #region PriceOracle

  const PriceOracleFactory = await ethers.getContractFactory("PriceOracle");
  // constructor(AggregatorV3Interface _priceFeed) {
  const PriceOracleBytecode = PriceOracleFactory.getDeployTransaction(USDCPriceFeedAddress).data;
  if (!PriceOracleBytecode) {
    throw new Error("PriceOracleBytecode not set");
  }
  const PriceOracleInitCodeHash = keccak256(PriceOracleBytecode);
  const PriceOracleAddress = getCreate2Address(soulWalletLib.singletonFactory, salt, PriceOracleInitCodeHash);
  console.log("PriceOracleAddress:", PriceOracleAddress);
  // if not deployed, deploy
  if (await ethers.provider.getCode(PriceOracleAddress) === '0x') {
    debugger;
    console.log("PriceOracle not deployed, deploying...");
    const increaseGasLimit = (estimatedGasLimit: BigNumber) => {
      let gasLimit = BigNumber.from(400000);
      if (network.name === 'arbitrum' || network.name === 'arbitrumGoerli') {
        gasLimit = gasLimit.mul(40);
      }
      return gasLimit;
      //return estimatedGasLimit.mul(10)
    }
    const create2FactoryContract = SingletonFactory__factory.connect(soulWalletLib.singletonFactory, EOA);
    const estimatedGas = await create2FactoryContract.estimateGas.deploy(PriceOracleBytecode, salt);
    const tx = await create2FactoryContract.deploy(PriceOracleBytecode, salt, { gasLimit: increaseGasLimit(estimatedGas) })
    console.log("EntryPoint tx:", tx.hash);
    while (await ethers.provider.getCode(PriceOracleAddress) === '0x') {
      console.log("PriceOracle not deployed, waiting...");
      await new Promise(r => setTimeout(r, 3000));
    }

    if (!isLocalTestnet()) {
      console.log("PriceOracle deployed, verifying...");
      await new Promise(r => setTimeout(r, 5000));
      if (!isLocalTestnet()) {
        debugger;
      }
      try {
        await run("verify:verify", {
          address: PriceOracleAddress,
          constructorArguments: [
            USDCPriceFeedAddress
          ],
        });
      } catch (error) {
        console.log("PriceOracle verify failed:", error);
      }
    }
  } else {
    console.log("PriceOracle already deployed at:" + PriceOracleAddress);
  }

  // #endregion PriceOracle

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
    debugger;
    console.log("TokenPaymaster not deployed, deploying...");
    const increaseGasLimit = (estimatedGasLimit: BigNumber) => {
      let gasLimit = BigNumber.from(3000000);
      if (network.name === 'arbitrum' || network.name === 'arbitrumGoerli') {
        gasLimit = gasLimit.mul(40);
      }
      return gasLimit;
      //return estimatedGasLimit.mul(10)
    }
    const create2FactoryContract = SingletonFactory__factory.connect(soulWalletLib.singletonFactory, EOA);
    const estimatedGas = await create2FactoryContract.estimateGas.deploy(TokenPaymasterBytecode, salt);
    const tx = await create2FactoryContract.deploy(TokenPaymasterBytecode, salt, { gasLimit: increaseGasLimit(estimatedGas) })
    console.log("tx:", tx.hash);
    while (await ethers.provider.getCode(TokenPaymasterAddress) === '0x') {
      console.log("TokenPaymaster not deployed, waiting...");
      await new Promise(r => setTimeout(r, 3000));
    }
    {
      let _paymasterStake = '' + Math.pow(10, 16);
      if (isLocalTestnet()) {
        _paymasterStake = '' + Math.pow(10, 17);
      }

      const TokenPaymaster = await TokenPaymaster__factory.connect(TokenPaymasterAddress, EOA);
      console.log(await TokenPaymaster.owner());
      let PriceOracleAddresses = [];
      for (let index = 0; index < USDCContractAddresses.length; index++) {
        PriceOracleAddresses.push(PriceOracleAddress);
      }
      await TokenPaymaster.setToken(USDCContractAddresses, PriceOracleAddresses);

      console.log('adding stake');
      if (!isLocalTestnet()) {
        debugger;
      }
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
      await new Promise(r => setTimeout(r, 5000));
      if (!isLocalTestnet()) {
        debugger;
      }
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
    console.log("TokenPaymaster already deployed at:" + TokenPaymasterAddress);
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
    debugger;
    console.log("GuardianLogic not deployed, deploying...");
    const increaseGasLimit = (estimatedGasLimit: BigNumber) => {
      let gasLimit = BigNumber.from(2000000);
      if (network.name === 'arbitrum' || network.name === 'arbitrumGoerli') {
        gasLimit = gasLimit.mul(40);
      }
      return gasLimit;
      //return estimatedGasLimit.mul(10)
    }
    const create2FactoryContract = SingletonFactory__factory.connect(soulWalletLib.singletonFactory, EOA);
    const estimatedGas = await create2FactoryContract.estimateGas.deploy(GuardianLogicBytecode, salt);
    const tx = await create2FactoryContract.deploy(GuardianLogicBytecode, salt, { gasLimit: increaseGasLimit(estimatedGas) })
    console.log("GuardianLogic tx:", tx.hash);
    while (await ethers.provider.getCode(GuardianLogicAddress) === '0x') {
      console.log("GuardianLogic not deployed, waiting...");
      await new Promise(r => setTimeout(r, 3000));
    }
    if (!isLocalTestnet()) {
      console.log("GuardianLogic deployed, verifying...");
      await new Promise(r => setTimeout(r, 5000));
      if (!isLocalTestnet()) {
        debugger;
      }
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
    console.log("GuardianLogic already deployed at:" + GuardianLogicAddress);
  }

  // #endregion GuardianLogic

  // #region deploy wallet without paymaster
  let bundlerUrl = networkBundler.get(network.name);
  if (!bundlerUrl && !isLocalTestnet()) {
    debugger;
    //throw new Error(`bundler rpc not found for network ${network.name}`);
  }
  const bundler = new soulWalletLib.Bundler(EntryPointAddress, ethers.provider, bundlerUrl || bundlerEOA.privateKey);
  await bundler.init();

  if (activateWalletTest) {


    const guardianWallet = [
      new ethers.Wallet("0x8d369779012545b04428bb23096d3937751dca4a51294b1f2e7a0eda56883773"),
      new ethers.Wallet("0x482611376d5e5b26d4b55ab6cf7b62124d27cfd5a84f43b4b37c58c182fcc12e"),
      new ethers.Wallet("0x742b9b2cc7d11fe6ea993506eca80b252987c47a791e90f8c0ef604b24776d67"),
      new ethers.Wallet("0xab62380f7a76b00a063a38a238e7341ee53896f339083a4f8ddf2c4cca8d0990"),
      new ethers.Wallet("0xad1b2410af8acd299ff66eed245158037a30804ea22354943f448efe79076d29"),
      new ethers.Wallet("0x6151a95f877c324b4ec0cfbb4d3c52092b63986a75f4e9bc92ed23514c550df2"),
      new ethers.Wallet("0x9271136613f8696f95ff3dabfdedb9d84b3e657b01ded330a97531c7189a8348"),
      new ethers.Wallet("0xd7161d46a0a52748a99b62eafe1dd802a51664e18fe4165a70663befce21d2f8")
    ];
    const guardians = [];
    const guardiansAddress = [];

    for (let i = 0; i < guardianWallet.length; i++) {
      const _account = guardianWallet[i];
      guardians.push({
        address: _account.address,
        privateKey: _account.privateKey
      });
      guardiansAddress.push(_account.address);
    }

    const guardianSalt = 'guardianSaltText <text or bytes32>';
    const gurdianAddressAndInitCode = soulWalletLib.Guardian.calculateGuardianAndInitCode(GuardianLogicAddress, guardiansAddress, Math.round(guardiansAddress.length / 2), guardianSalt);

    const upgradeDelay = 10;
    const guardianDelay = 10;

    const walletAddress = await soulWalletLib.calculateWalletAddress(
      WalletLogicAddress,
      EntryPointAddress,
      walletOwner,
      upgradeDelay,
      guardianDelay,
      gurdianAddressAndInitCode.address || SoulWalletLib.Defines.AddressZero
    );
    {
      const walletAddress_online = await WalletFactory.contract.getWalletAddress(
        EntryPointAddress,
        walletOwner,
        guardianDelay,
        upgradeDelay,
        gurdianAddressAndInitCode.address || SoulWalletLib.Defines.AddressZero,
        SoulWalletLib.Defines.bytes32_zero
      );
      if (walletAddress_online !== walletAddress) {
        throw new Error('walletAddress_online !== walletAddress');
      }
    }

    console.log('walletAddress: ' + walletAddress);

    // check if wallet is activated (deployed) 
    const code = await ethers.provider.getCode(walletAddress);

    if (code === "0x") {
      debugger;
      const activateOp = soulWalletLib.activateWalletOp(
        WalletLogicAddress,
        EntryPointAddress,
        walletOwner,
        upgradeDelay,
        guardianDelay,
        gurdianAddressAndInitCode.address || SoulWalletLib.Defines.AddressZero,
        '0x',
        ethers.utils
          .parseUnits(eip1559GasFee.high.suggestedMaxFeePerGas, "gwei")
          .toString(),
        ethers.utils
          .parseUnits(eip1559GasFee.high.suggestedMaxPriorityFeePerGas, "gwei")
          .toString()
      );

      await estimateUserOperationGas(bundler, activateOp);

      const _requiredPrefund = await activateOp.requiredPrefund(ethers.provider, EntryPointAddress);
      const requiredPrefund = _requiredPrefund.requiredPrefund.sub(_requiredPrefund.deposit);
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


      const userOpHash = activateOp.getUserOpHashWithTimeRange(EntryPointAddress, chainId, walletOwner);
      activateOp.signWithSignature(
        walletOwner,
        Utils.signMessage(userOpHash, walletOwnerPrivateKey)
      );
      const validation = await bundler.simulateValidation(activateOp);
      if (validation.status !== 0) {
        debugger;
        throw new Error(`error code:${validation.status}`);
      }
      const simulate = await bundler.simulateHandleOp(activateOp);
      if (simulate.status !== 0) {
        debugger;
        throw new Error(`error code:${simulate.status}`);
      }
      let activated = false;

      const bundlerEvent = bundler.sendUserOperation(activateOp, 1000 * 60 * 3);
      bundlerEvent.on('error', (err: any) => {
        console.log(err);
        debugger;
      });
      bundlerEvent.on('send', (userOpHash: string) => {
        console.log('send: ' + userOpHash);
      });
      bundlerEvent.on('receipt', (receipt: IUserOpReceipt) => {
        console.log('receipt: ' + receipt);
        activated = true;
        debugger;
      });
      bundlerEvent.on('timeout', () => {
        console.log('timeout');
      });



      while (!activated) {
        await new Promise((resolve) => setTimeout(resolve, 1000));
      }


      // verify wallet
      if (activated && !isLocalTestnet()) {

        let iface = new ethers.utils.Interface(SoulWallet__factory.abi);
        let initializeData = iface.encodeFunctionData("initialize", [EntryPointAddress, walletOwner, upgradeDelay, guardianDelay, SoulWalletLib.Defines.AddressZero,]);

        await new Promise(r => setTimeout(r, 5000));
        debugger;
        try {
          await run("verify:verify", {
            address: walletAddress,
            constructorArguments: [WalletLogicAddress, initializeData],
          });
        } catch (error) {
          console.log("WalletLogic verify failed:", error);
        }
      }
    }

    if (recoverWalletTest) {
      debugger;
      const nonce = await soulWalletLib.Utils.getNonce(walletAddress, ethers.provider);
      const newWalletOwner = new ethers.Wallet("0x42e227223702c6a3f7a5834df80b01b814c811f16267f17990145461bc63820b");
      const transferOwnerOP = await soulWalletLib.Guardian.transferOwner(
        walletAddress,
        nonce,
        '0x',
        ethers.utils
          .parseUnits(eip1559GasFee.high.suggestedMaxFeePerGas, "gwei")
          .toString(),
        ethers.utils
          .parseUnits(eip1559GasFee.high.suggestedMaxPriorityFeePerGas, "gwei")
          .toString(),
        newWalletOwner.address
      );
      await estimateUserOperationGas(bundler, transferOwnerOP);

      const transferOwnerOPuserOpHash = transferOwnerOP.getUserOpHashWithTimeRange(EntryPointAddress, chainId, walletOwner);
      const guardianSignArr: any[] = [];
      for (let index = 0; index < Math.round(guardians.length / 2); index++) {
        const _guardian = guardians[index];
        const _address = _guardian.address;
        const _privateKey = _guardian.privateKey;
        guardianSignArr.push(
          {
            contract: false,
            address: _address,
            signature: Utils.signMessage(transferOwnerOPuserOpHash, _privateKey)
          }
        );
      }
      const signature = soulWalletLib.Guardian.packGuardiansSignByInitCode(gurdianAddressAndInitCode.address, guardianSignArr, gurdianAddressAndInitCode.initCode);
      transferOwnerOP.signature = signature;

      {
        const _requiredPrefund = await transferOwnerOP.requiredPrefund(ethers.provider, EntryPointAddress);
        const requiredPrefund = _requiredPrefund.requiredPrefund.sub(_requiredPrefund.deposit);
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

      }

      const validation = await bundler.simulateValidation(transferOwnerOP);
      if (validation.status !== 0) {
        debugger;
        throw new Error(`error code:${validation.status}`);
      }
      const simulate = await bundler.simulateHandleOp(transferOwnerOP);
      if (simulate.status !== 0) {
        debugger;
        throw new Error(`error code:${simulate.status}`);
      }



    }


  }


  // #endregion deploy wallet

  // #region deploy wallet with paymaster
  if (activateWalletWithPaymasterTest) {
    debugger;
    const upgradeDelay = 10;
    const guardianDelay = 10;
    const salt = 0;
    const walletAddress = await soulWalletLib.calculateWalletAddress(
      WalletLogicAddress,
      EntryPointAddress,
      walletOwner,
      upgradeDelay,
      guardianDelay,
      SoulWalletLib.Defines.AddressZero,
      salt
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
        TokenPaymasterAddress,
        ethers.utils
          .parseUnits(eip1559GasFee.high.suggestedMaxFeePerGas, "gwei")
          .toString(),
        ethers.utils
          .parseUnits(eip1559GasFee.high.suggestedMaxPriorityFeePerGas, "gwei")
          .toString()
        , salt
      );
      const approveData = [];
      for (let i = 0; i < USDCContractAddresses.length; i++) {
        approveData.push({
          token: USDCContractAddresses[i],
          spender: TokenPaymasterAddress,
          value: ethers.utils.parseEther('100').toString()
        });
      }
      const approveCallData = soulWalletLib.Tokens.ERC20.getApproveCallData(approveData);
      activateOp.callData = approveCallData.callData;
      activateOp.callGasLimit = approveCallData.callGasLimit;

      await estimateUserOperationGas(bundler, activateOp);


      // calculate eth cost
      const _requiredPrefund = await activateOp.requiredPrefund(ethers.provider, EntryPointAddress);
      const requiredPrefund = _requiredPrefund.requiredPrefund.sub(_requiredPrefund.deposit);
      console.log('requiredPrefund: ' + ethers.utils.formatEther(requiredPrefund) + ' ETH');
      // get USDC exchangeRate
      const exchangePrice = await soulWalletLib.getPaymasterExchangePrice(ethers.provider, TokenPaymasterAddress, USDCContractAddresses[0], true);
      const tokenDecimals = exchangePrice.tokenDecimals || 6;
      // print price now
      console.log('exchangePrice: ' + ethers.utils.formatUnits(exchangePrice.price, exchangePrice.decimals), 'USDC/ETH');
      // get required USDC : (requiredPrefund/10^18) * (exchangePrice.price/10^exchangePrice.decimals)
      let requiredUSDC = requiredPrefund.mul(exchangePrice.price)
        .mul(BigNumber.from(10).pow(tokenDecimals))
        .div(BigNumber.from(10).pow(exchangePrice.decimals))
        .div(BigNumber.from(10).pow(18));
      if (requiredUSDC.eq(0)) {
        requiredUSDC = BigNumber.from(Math.pow(1, tokenDecimals));
      }
      const maxUSDC = requiredUSDC.mul(110).div(100); // 10% more
      console.log('requiredUSDC: ' + ethers.utils.formatUnits(maxUSDC, tokenDecimals), 'USDC');
      let paymasterAndData = soulWalletLib.getPaymasterData(TokenPaymasterAddress, USDCContractAddresses[0], maxUSDC);
      activateOp.paymasterAndData = paymasterAndData;


      const USDCContract = await ethers.getContractAt("USDCoin", USDCContractAddresses[0]);
      const _balance = await USDCContract.balanceOf(walletAddress);
      if (_balance.lt(maxUSDC)) {
        const _requiredfund = maxUSDC.sub(_balance);
        console.log('sending ' + ethers.utils.formatUnits(_requiredfund, exchangePrice.tokenDecimals) + ' USD to wallet');

        await USDCContract.transfer(walletAddress, maxUSDC);
        // get balance of USDC
        const usdcBalance = await USDCContract.balanceOf(walletAddress);
        console.log('usdcBalance: ' + ethers.utils.formatUnits(usdcBalance, exchangePrice.tokenDecimals), 'USD');
      }
      

      const userOpHash = activateOp.getUserOpHashWithTimeRange(EntryPointAddress, chainId, walletOwner);
      activateOp.signWithSignature(
        walletOwner,
        Utils.signMessage(userOpHash, walletOwnerPrivateKey)
      );
      const validation = await bundler.simulateValidation(activateOp);
      if (validation.status !== 0) {
        debugger;
        throw new Error(`error code:${validation.status}`);
      }
      const simulate = await bundler.simulateHandleOp(activateOp);
      if (simulate.status !== 0) {
        debugger;
        throw new Error(`error code:${simulate.status}`);
      }
      let finish = false;
      const bundlerEvent = bundler.sendUserOperation(activateOp, 1000 * 60 * 3);
      bundlerEvent.on('error', (err: any) => {
        console.log(err);
        finish = true;
        debugger;
      });
      bundlerEvent.on('send', (userOpHash: string) => {
        console.log('send: ' + userOpHash);
      });
      bundlerEvent.on('receipt', (receipt: IUserOpReceipt) => {
        console.log('receipt: ' + receipt);
        finish = true;
        debugger;
      });
      bundlerEvent.on('timeout', () => {
        finish = true;
        console.log('timeout');
      });

      while (!finish) {
        await new Promise((resolve) => setTimeout(resolve, 1000));
      }





    }
  }

  // #endregion deploy wallet


}


main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});