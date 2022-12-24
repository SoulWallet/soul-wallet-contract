/*
 * @Description: 
 * @Version: 1.0
 * @Autor: daivd.ding
 * @Date: 2022-10-21 11:06:42
 * @LastEditors: cejay
 * @LastEditTime: 2022-12-24 14:23:26
 */
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

/** @type import('hardhat/config').HardhatUserConfig */
const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.17',
    overrides: {
      "contracts/SoulWalletProxy.sol": {
        version: '0.8.17',
        settings: {
          optimizer: {
            enabled: true,
            runs: 1
          },
        },
      },
    },
    settings: {
      optimizer: {
        enabled: true,
        runs: 2000
      }
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
      }
    },
    localhost: {
      allowUnlimitedContractSize: true,
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
};

export default config;