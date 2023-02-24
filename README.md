<div align="center">
  <h1 align="center">SoulWallet Contracts</h1>
</div>

<div align="center">
<img src="https://raw.githubusercontent.com/proofofsoulprotocol/soul-wallet-packages/main/src/assets/logo.svg">
</div>

## Features
+ Support [ERC-4337: Account Abstraction](https://eips.ethereum.org/EIPS/eip-4337)
+ Social Recovery with Anonymous Guardians: Users can specify trusted contacts, or guardians, when creating a wallet. These guardians are anonymous and are only revealed on-chain during a recovery process, providing some level of privacy. The anonymous guardian setup can help prevent vulnerability to social attacks that attempt to gain control of the wallet by targeting the guardians.
+ Upgradability: The smart contract for this wallet can be upgraded in a secure way to add new features or fix vulnerabilities in the future.
+ Stablecoin pay gas: Users can pay transaction gas fees with stablecoins such as USDC, USDT, DAI, etc.

## Repository overview

Below is a brief overview of the repository contracts

### SoulWalletFactory

"SoulWalletFactory" is a factory contract. It is used to create a new wallet contract. The wallet contract is created using the singleton contract with the CREATE2 opcode, which allows the wallet contract to be created with a deterministic address.

### SoulWalletProxy
"SoulWalletProxy" is a proxy contract that manages the implementation contract address and is responsible for forwarding delegate calls to the implementation contract. Additionally, users' contract wallet data is stored in the proxy contract.

### SoulWallet
"SoulWallet" is the implementation contract. It is responsible for the core logic of the wallet
+ Using diamond storage pattern to store the data. All contract data is stored in specific slots in the contract. This approach has the advantage of making it easier to upgrade the logic contract in the future while avoiding data conflicts in slots compare the default contract storage from slot 0.
+ Guardian management.
  1. The initial guardian settings take effect immediately. If guardians are updated, there is a time lock, meaning that changes will only take effect after the set time has passed.
  2. During social recovery, an anonymous guardian multi-signature contract is deployed, and the guardian's signatures are verified. If the signatures are all correct, social recovery is successful, and the signing key of the wallet contract is replaced.
  3. Execute transactions from the entry point, the wallet contract will first verify the transaction or user operation signature and then execute the call to the target contract.
+ Upgradability: The smart contract for this wallet can be upgraded in a secure way to add new features or fix vulnerabilities in the future. SoulWallet can be upgraded to a new logic contract. The upgrade process also has a time lock, which means that the upgrade can only be successful after the set time has passed.

| Method                        | Owner  | Guardians| Anyone | Comment                                                                                         |
| ----------------------------  | ------ | ------   | ------ | ----------------------------------------------------------------------------------------------- |
| `transferOwner`               | X      | X        |        |  The owner has the ability to replace the signing key, and the guardians (multi-signature contract) can also replace the signing key through social recovery.
|`setGuardian`     | X      |          |        |  The owner can update the guardians.                                               |
| `preUpgradeTo`              | X      |          |        |  Let the owner perform a contract upgrade                                             |
| `upgrade`            |        |          |   X    | Finalizes an ongoing contract upgrade if the set time period has elapsed. The method is public and can be called by anyone. |

### AccountStorage
"AccountStorage" is a library contract that uses the diamond storage pattern to store data in a particular position in the contract storage.

### GuardianMultiSigWallet
"GuardianMultiSigWallet" is a multi-signature contract that is used to verify the signatures of the guardians during social recovery. This multi-sig wallet is only deployed on the fly during social recovery, and guardians are only revealed at that point.

### TokenPaymaster
"TokenPaymaster" is a paymaster contract that is used to pay gas fees with stablecoins such as USDC, USDT, DAI, etc.

## Test
```shell
npm run test
```

```shell
npm run deploy:optimisticGoerli
```
## Disclaimer
This project is provided "as is" with no warranties or guarantees of any kind, express or implied. The developers make no claims about the suitability, reliability, availability, timeliness, security or accuracy of the software or its related documentation. The use of this software is at your own risk.

The developers will not be liable for any damages or losses, whether direct, indirect, incidental or consequential, arising from the use of or inability to use this software or its related documentation, even if advised of the possibility of such damages.

## Acknowledgments
* <a href='https://eips.ethereum.org/EIPS/eip-4337'>ERC-4337: Account Abstraction Using Alt Mempool</a>
* <a href='https://github.com/eth-infinitism/account-abstraction'>Infinitism account abstraction contract</a>
* <a href='https://github.com/safe-global/safe-contracts'>Gnosis Safe Contracts</a>