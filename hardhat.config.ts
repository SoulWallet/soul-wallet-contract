import * as dotenv from 'dotenv'
dotenv.config()

import 'solidity-coverage';
import "@nomicfoundation/hardhat-toolbox";

import { TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS } from "hardhat/builtin-tasks/task-names";
import { HardhatUserConfig , subtask } from "hardhat/config";
import * as path from 'path'

subtask(
  TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS,
  async (_, { config }, runSuper) => {
    const paths = await runSuper();

    return paths
      .filter((solidityFilePath:any) => {
        const relativePath = path.relative(config.paths.sources, solidityFilePath)
        return !relativePath.includes("modules/");
      })
  }
);


/** @type import('hardhat/config').HardhatUserConfig */
const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 100000
          },
          viaIR: true
        }
      }
    ],
    overrides: {
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
    }
  },
  mocha: {
    timeout: 100000000
  }
};

export default config;