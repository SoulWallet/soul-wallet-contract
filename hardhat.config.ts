/*
 * @Description: 
 * @Version: 1.0
 * @Autor: daivd.ding
 * @Date: 2022-10-21 11:06:42
 * @LastEditors: cejay
 * @LastEditTime: 2023-03-01 11:15:03
 */
import * as dotenv from 'dotenv'
dotenv.config()

import 'solidity-coverage';
import "@nomicfoundation/hardhat-toolbox";
import { HardhatUserConfig } from "hardhat/config";
const GOERLI_PRIVATE_KEY =
  process.env.GOERLI_PRIVATE_KEY! ||
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"; // test private key
const MAINNET_PRIVATE_KEY =
  process.env.MAINNET_PRIVATE_KEY! ||
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"; // test private key
  const ARBGOERLI_ONE_PRIVATE_KEY =
  process.env.ARBGOERLI_ONE_PRIVATE_KEY! ||
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
  const ARBGOERLI_GOERLI_PRIVATE_KEY =
  process.env.ARBGOERLI_GOERLI_PRIVATE_KEY! ||
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
const OPGOERLI_PRIVATE_KEY =
  process.env.OPGOERLI_PRIVATE_KEY! ||
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
const OPTIMISM_PRIVATE_KEY =
  process.env.OPTIMISM_PRIVATE_KEY! ||
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";


  const optimizedComilerSettings = {
    version: '0.8.17',
    settings: {
      optimizer: { enabled: true, runs: 1000000 },
      viaIR: true
    }
  }
  const entrypointRelatedComilerSettings = {
    version: '0.8.15',
    settings: {
      optimizer: { enabled: true, runs: 1000000 },
      viaIR: true
    }
  }

/** @type import('hardhat/config').HardhatUserConfig */
const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 50000
          },
          viaIR: true
        }
      }
    ],
    overrides: {
      "contracts/entrypoint/EntryPoint.sol": optimizedComilerSettings,
      "contracts/utils/Exec.sol": entrypointRelatedComilerSettings,
      "contracts/entrypoint/StakeManager.sol": entrypointRelatedComilerSettings,
      "contracts/entrypoint/SenderCreator.sol": entrypointRelatedComilerSettings,
      "contracts/entrypoint/Helpers.sol": entrypointRelatedComilerSettings,
    }
  },
  typechain: {
    outDir: 'src/types',
    target: 'ethers-v5',
    alwaysGenerateOverloads: false, // should overloads with full signatures like deposit(uint256) be generated always, even if there are no overloads?
    externalArtifacts: ['externalArtifacts/*.json'], // optional array of glob patterns with external artifacts to process (for example external libs from node_modules)
    dontOverrideCompile: false // defaults to false
  },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      accounts: {
        mnemonic: 'test test test test test test test test test test test junk',
        initialIndex: 0,
        accountsBalance: '10000000000000000000000000' // 10,000,000 ETH
      },
    },
    localhost: {
      allowUnlimitedContractSize: true,
    },
    goerli: {
      url: process.env.ETH_GOERLI_PROVIDER,
      accounts: [GOERLI_PRIVATE_KEY],
      gasPrice: "auto",
      timeout: 1000000
    },
    mainnet: {
      url: process.env.ETH_MAINNET_PROVIDER || "",
      accounts: [MAINNET_PRIVATE_KEY],
      gasPrice: "auto",
      timeout: 1000000
    },
    arbitrum: {
      url: process.env.ARBITRUM_ONE_PROVIDER || "https://arb1.arbitrum.io/rpc",
      accounts: [ARBGOERLI_ONE_PRIVATE_KEY],
      gasPrice: "auto",
      timeout: 1000000
    },
    arbitrumGoerli: {
      url: process.env.ARBITRUM_GOERLI_PROVIDER || "https://goerli-rollup.arbitrum.io/rpc",
      accounts: [ARBGOERLI_GOERLI_PRIVATE_KEY],
      gasPrice: "auto",
      timeout: 1000000
    },
    optimisticGoerli:{
      url: process.env.OPTIMISM_GOERLI_PROVIDER || "https://endpoints.omniatech.io/v1/op/goerli/public",
      accounts: [OPGOERLI_PRIVATE_KEY],
      gasPrice: "auto",
      timeout: 1000000
    },
    optimistic:{
      url: process.env.OPTIMISM_MAINNET_PROVIDER || "https://mainnet.optimism.io",
      accounts: [OPTIMISM_PRIVATE_KEY],
      gasPrice: "auto",
      timeout: 1000000
    }

  },
  etherscan: {
    apiKey: {
      optimisticEthereum: process.env.OPTIMISM_API_KEY || process.env.ETHERSCAN_API_KEY || "",
      optimisticGoerli: process.env.OPTIMISM_API_KEY || process.env.ETHERSCAN_API_KEY || "",
      arbitrumOne: process.env.ARBGOERLI_API_KEY || process.env.ETHERSCAN_API_KEY || "",
      arbitrumGoerli: process.env.ARBGOERLI_API_KEY || process.env.ETHERSCAN_API_KEY || "",
      goerli: process.env.GOERLI_API_KEY || process.env.ETHERSCAN_API_KEY || ""
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  gasReporter: {
    currency: 'USD',
    coinmarketcap: process.env.COINMARKETCAP_API_KEY || "",
    enabled: true
  }
};

export default config;