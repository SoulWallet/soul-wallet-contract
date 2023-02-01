/*
 * @Description: 
 * @Version: 1.0
 * @Autor: z.cejay@gmail.com
 * @Date: 2022-12-26 23:06:27
 * @LastEditors: cejay
 * @LastEditTime: 2023-02-01 13:12:37
 */

import { BigNumber } from "ethers";
import { getCreate2Address, hexlify, hexZeroPad, keccak256 } from "ethers/lib/utils";
import { ethers, network, run } from "hardhat";
import { EIP4337Lib } from 'soul-wallet-lib';
import { USDCoin__factory , USDCPaymaster__factory, Create2Factory__factory, EntryPoint__factory, ERC20__factory } from "../src/types/index";
import { Utils } from "../test/Utils";

function isLocalTestnet() {
    return network.name === "localhost" || network.name === "hardhat"
}

async function main() {
    let mockGasFee = {
        "low": {
          "suggestedMaxPriorityFeePerGas": "1",
          "suggestedMaxFeePerGas": "16.984563596",
          "minWaitTimeEstimate": 15000,
          "maxWaitTimeEstimate": 30000
        },
        "medium": {
          "suggestedMaxPriorityFeePerGas": "1.5",
          "suggestedMaxFeePerGas": "23.079160855",
          "minWaitTimeEstimate": 15000,
          "maxWaitTimeEstimate": 45000
        },
        "high": {
          "suggestedMaxPriorityFeePerGas": "2",
          "suggestedMaxFeePerGas": "29.173758114",
          "minWaitTimeEstimate": 15000,
          "maxWaitTimeEstimate": 60000
        },
        "estimatedBaseFee": "15.984563596",
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

    // npx hardhat run --network goerli scripts/deploy.ts
    // npx hardhat run --network ArbGoerli scripts/deploy.ts

    let create2Factory = '0xce0042B868300000d44A59004Da54A005ffdcf9f';
    let USDCContractAddress = '';
    let USDCPriceFeedAddress = '';

    let EOA=(await ethers.getSigners())[0];

    // print EOA Address
    console.log("EOA Address:", EOA.address);

    if (network.name === "mainnet") {

      USDCContractAddress = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
      
    } else if (network.name === "goerli") {

      USDCContractAddress = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";

    } else if(network.name ==="ArbGoerli"){

      USDCContractAddress = "0xe34a90dF83c29c28309f58773C41122d4E8C757A";
      //https://docs.chain.link/data-feeds/price-feeds/addresses/?network=arbitrum
      USDCPriceFeedAddress = "0x62CAe0FA2da220f43a51F86Db2EDb36DcA9A5A08";

    } else if (isLocalTestnet()) {
      let create2 = await new Create2Factory__factory(EOA).deploy();
      create2Factory = create2.address;
      let usdc = await new USDCoin__factory(EOA).deploy();
      USDCContractAddress = usdc.address;
      USDCPriceFeedAddress =  await (await (await ethers.getContractFactory("USDCPriceFeed")).deploy()).address;
    }


    if (!create2Factory) {
        throw new Error("create2Factory not set");
    }

    if (!USDCContractAddress) {
        throw new Error("USDCContractAddress not set");
    }

    if (!USDCPriceFeedAddress) {
        throw new Error("USDCPriceFeedAddress not set(ChainLink Price Feed)");
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
        if(!isLocalTestnet()){
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

        if(!isLocalTestnet()){
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


    // #region USDCPaymaster 

    const USDCPaymasterFactory = await ethers.getContractFactory("USDCPaymaster");
    const USDCPaymasterBytecode = USDCPaymasterFactory.getDeployTransaction(EntryPointAddress, USDCContractAddress, USDCPriceFeedAddress, EOA.address).data;
    if (!USDCPaymasterBytecode) {
        throw new Error("USDCPaymasterBytecode not set");
    }
    const USDCPaymasterInitCodeHash = keccak256(USDCPaymasterBytecode);
    const USDCPaymasterAddress = getCreate2Address(create2Factory, salt, USDCPaymasterInitCodeHash);
    console.log("USDCPaymasterAddress:", USDCPaymasterAddress);
    // if not deployed, deploy
    if (await ethers.provider.getCode(USDCPaymasterAddress) === '0x') {
        console.log("USDCPaymaster not deployed, deploying...");
        const increaseGasLimit = (estimatedGasLimit: BigNumber) => {
            return ethers.BigNumber.from(Math.pow(10, 7) + '');
            //return estimatedGasLimit.mul(10)  // 10x gas
        }
        const create2FactoryContract = Create2Factory__factory.connect(create2Factory, EOA);
        const estimatedGas = await create2FactoryContract.estimateGas.deploy(USDCPaymasterBytecode, salt);
        const tx = await create2FactoryContract.deploy(USDCPaymasterBytecode, salt, { gasLimit: increaseGasLimit(estimatedGas) })
        console.log("EntryPoint tx:", tx.hash);
        while (await ethers.provider.getCode(USDCPaymasterAddress) === '0x') {
            console.log("USDCPaymaster not deployed, waiting...");
            await new Promise(r => setTimeout(r, 3000));
        }
        {
            const _paymasterStake = '' + Math.pow(10, 17);
            const USDCPaymaster = await USDCPaymaster__factory.connect(USDCPaymasterAddress, EOA);
            console.log(await USDCPaymaster.owner());

            // addKnownWalletLogic
            // get SoulWalletLogic contract code
            const SoulWalletLogicCode = await ethers.provider.getCode(WalletLogicAddress);
            // calculate SoulWalletLogic contract code hash
            const SoulWalletLogicCodeHash = ethers.utils.keccak256(SoulWalletLogicCode);
            await USDCPaymaster.addKnownWalletLogic([SoulWalletLogicCodeHash]);

            console.log('adding stake');
            await USDCPaymaster.addStake(
                1, {
                from: EOA.address,
                value: _paymasterStake
            });
            await USDCPaymaster.deposit({
                from: EOA.address,
                value: _paymasterStake
            });
        } 

        if(!isLocalTestnet()){
          console.log("USDCPaymaster deployed, verifying...");
          try {
              await run("verify:verify", {
                  address: USDCPaymasterAddress,
                  constructorArguments: [
                      EntryPointAddress, USDCContractAddress, EOA.address
                  ],
              });
          } catch (error) {
              console.log("USDCPaymaster verify failed:", error);
          }
        }
    } else {
         
    }


    // #endregion USDCPaymaster

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
        if(!isLocalTestnet()){
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

    const upgradeDelay = 10;
    const guardianDelay = 10;
    const walletAddress = await EIP4337Lib.calculateWalletAddress(
        WalletLogicAddress,
        EntryPointAddress,
        walletOwner,
        upgradeDelay,
        guardianDelay,
        EIP4337Lib.Defines.AddressZero,
        0,
        create2Factory
    );

    console.log('walletAddress: ' + walletAddress);



    // send 0.02 USDC to wallet
    const USDCContract = USDCoin__factory.connect(USDCContractAddress, EOA);
    const _b = await USDCContract.balanceOf(walletAddress);
    if (_b.lt(ethers.utils.parseEther('0.02'))) {
        console.log('sending 0.05 USDC to wallet');
        await USDCContract.transfer(walletAddress, ethers.utils.parseEther('0.05'),{
            from: EOA.address
        });
    }



    // check if wallet is activated (deployed) 
    const code = await ethers.provider.getCode(walletAddress);
    if (code === "0x") {
      // get gas price
      let eip1559GasFee: any;
      if (!isLocalTestnet()) {
        eip1559GasFee =
          await EIP4337Lib.Utils.suggestedGasFee.getEIP1559GasFees(chainId);
        if (!eip1559GasFee) {
          throw new Error("eip1559GasFee is null");
        }
      } else {
        eip1559GasFee = mockGasFee;
      }

      const activateOp = EIP4337Lib.activateWalletOp(
        WalletLogicAddress,
        EntryPointAddress,
        walletOwner,
        upgradeDelay,
        guardianDelay,
        EIP4337Lib.Defines.AddressZero,
        USDCPaymasterAddress,
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

      const approveCallData = await EIP4337Lib.Tokens.ERC20.getApproveCallData(ethers.provider, walletAddress, USDCContractAddress, USDCPaymasterAddress, 1e18.toString());
      activateOp.callData = approveCallData.callData;
      activateOp.callGasLimit = approveCallData.callGasLimit;

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
      const re = await EntryPoint.handleOps([activateOp], EOA.address);
      console.log(re);
    }

    // #endregion deploy wallet

    // #region send 1wei USDC to wallet
    const nonce = await EIP4337Lib.Utils.getNonce(walletAddress, ethers.provider);
    let eip1559GasFee: any;
    if (!isLocalTestnet()) {
      eip1559GasFee = await EIP4337Lib.Utils.suggestedGasFee.getEIP1559GasFees(
        chainId
      );
      if (!eip1559GasFee) {
        throw new Error("eip1559GasFee is null");
      }
    } else {
      eip1559GasFee = mockGasFee;
    }

    const sendUSDCOP = await EIP4337Lib.Tokens.ERC20.transfer(
        ethers.provider,
        walletAddress,
        nonce,
        EntryPointAddress,
        USDCPaymasterAddress,
        ethers.utils.parseUnits(eip1559GasFee.medium.suggestedMaxFeePerGas, 'gwei').toString(),
        ethers.utils.parseUnits(eip1559GasFee.medium.suggestedMaxPriorityFeePerGas, 'gwei').toString(),
        USDCContractAddress,
        EOA.address,
        '1'
    );
    if (!sendUSDCOP) {
        throw new Error('sendUSDCOP is null');
    }
    const userOpHash = sendUSDCOP.getUserOpHash(EntryPointAddress, chainId);
    sendUSDCOP.signWithSignature(
        walletOwner,
        Utils.signMessage(userOpHash, walletOwnerPrivateKey)
    );
    await EIP4337Lib.RPC.simulateHandleOp(ethers.provider, EntryPointAddress, sendUSDCOP);
    const EntryPoint = EntryPoint__factory.connect(EntryPointAddress, EOA);
    console.log(sendUSDCOP);
    const re = await EntryPoint.handleOps([sendUSDCOP], EOA.address);
    console.log(re);

    // #endregion send 1wei usdc to wallet


}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});