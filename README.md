<div align="center">
  <h1 align="center">SoulWallet Contracts [draft version]</h1>  
</div>

<div align="center">
<img src="https://github.com/SoulWallet/soul-wallet-contract/assets/1399563/8678c33d-2e86-4cd8-99b3-4a856e8ee60e">
</div>

## Features
+ Support [ERC-4337: Account Abstraction](https://eips.ethereum.org/EIPS/eip-4337)
+ [Modular design ](https://hackmd.io/3gbndH7tSl2J1EbNePJ3Yg)
+ Implement [asset / keystore](https://hackmd.io/-YY8jD7IQ7qfEZaDepXZsA?view) separation architecture 
+ Upgradability: The smart contract for this wallet can be upgraded in a secure way to add new features or fix vulnerabilities in the future.
+ Stablecoin pay gas: Users can pay transaction gas fees with stablecoins such as USDC, USDT, DAI, etc.

## Architecutre
![architecure](https://github.com/SoulWallet/soul-wallet-contract/assets/1399563/0e22bd9f-4438-475c-93f0-3f35a3c19c27)


The smart contract comprises three main logic components:

1. SoulWallet Core:

+ This is the primary wallet logic.
+ Handles signature validation.
+ Supports the ERC4337 interface.
+ Manages modules and plugins.
2. Modules:

+ Modules provide extended functionality.
+ A module is a whitelisted contract capable of executing transactions on behalf of the smart contract wallet.
+ Modules enhance the functionality of the contracts by adding extra access logic for transaction execution.
3. Plugins (Hooks):

+ Plugins empower the smart contract wallet to invoke calls to the plugin contract.
+ Plugins can be set up to perform additional checks on transactions before they're executed.
+ There are three defined hook points within the contract wallet. `guardHook` `preHook` `postHook`. The `prehook` and `posthook` are executed before and after the execution of a transaction, while the `guardhook` is executed before signature validation.


## Repository Structure

All contracts are held within the `soul-wallet-contract/contracts` folder.
 

```
contracts
├── authority
├── base
├── handler
├── helper
├── interfaces
├── keystore
│   ├── L1
│   │   └── interfaces
│   └── interfaces
├── libraries
├── miscellaneous
├── modules
│   ├── SecurityControlModule
│   ├── SocialRecoveryModule
│   ├── Upgrade
│   └── keystore
│       ├── ArbitrumKeyStoreModule
│       └── OptimismKeyStoreProofModule
├── paymaster
│   └── interfaces
├── plugin
│   ├── Dailylimit
│   └── Simple2FA
├── safeLock
└── trustedContractManager
    ├── trustedModuleManager
    └── trustedPluginManager
```

## Test
```shell
npm run test
```

## Integration
Third parties can build new modules/plugins on top of SoulWallet to add additional functionality. 
### Module
To add a new module, the contract can inherit from `BaseModule`
``` solidity
import "./BaseModule.sol";

contract NewModule is BaseModule {
    function requiredFunctions()
        external
        pure
        override
        returns (bytes4[] memory)
    {}

    function inited(
        address wallet
    ) internal view virtual override returns (bool) {}

    function _init(bytes calldata data) internal virtual override {}

    function _deInit() internal virtual override {}
}

```
### Plugin
To add a new plugin, the contract can inherit from `BasePlugin`
``` solidity
import "./BasePlugin.sol";

contract NewPlugin is BasePlugin {
    function guardHook(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        bytes calldata guardData
    ) external override {}

    function preHook(
        address target,
        uint256 value,
        bytes calldata data
    ) external override {}

    function postHook(
        address target,
        uint256 value,
        bytes calldata data
    ) external override {}

    function _init(bytes calldata data) internal virtual override {}

    function _deInit() internal virtual override {}

    function _supportsHook()
        internal
        pure
        virtual
        override
        returns (uint8 hookType)
    {}

    function inited(
        address wallet
    ) internal view virtual override returns (bool) {}
}
```
## Disclaimer
This project is provided "as is" with no warranties or guarantees of any kind, express or implied. The developers make no claims about the suitability, reliability, availability, timeliness, security or accuracy of the software or its related documentation. The use of this software is at your own risk.

The developers will not be liable for any damages or losses, whether direct, indirect, incidental or consequential, arising from the use of or inability to use this software or its related documentation, even if advised of the possibility of such damages.

## Acknowledgments
* <a href='https://eips.ethereum.org/EIPS/eip-4337'>ERC-4337: Account Abstraction Using Alt Mempool</a>
* <a href='https://github.com/eth-infinitism/account-abstraction'>Infinitism account abstraction contract</a>
* <a href='https://github.com/safe-global/safe-contracts'>Gnosis Safe Contracts</a>
