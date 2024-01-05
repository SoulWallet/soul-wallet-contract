<div align="center">
  <h1 align="center">SoulWallet Contracts [draft version]</h1>  
</div>

<div align="center">
<img src="https://github.com/SoulWallet/soul-wallet-contract/assets/1399563/8678c33d-2e86-4cd8-99b3-4a856e8ee60e">
</div>

## Features

- Support [ERC-4337: Account Abstraction](https://eips.ethereum.org/EIPS/eip-4337)
- [Modular design ](https://hackmd.io/3gbndH7tSl2J1EbNePJ3Yg)
- Implement [asset / keystore](https://hackmd.io/-YY8jD7IQ7qfEZaDepXZsA?view) separation architecture
- Upgradability: The smart contract for this wallet can be upgraded in a secure way to add new features or fix vulnerabilities in the future.
- Stablecoin pay gas: Users can pay transaction gas fees with stablecoins such as USDC, USDT, DAI, etc.

## Architecutre

The smart contract comprises three main logic components:

1. SoulWallet Core:

- This is the primary wallet logic.
- Supports the ERC4337 interface.
- Manages modules and hooks.

2. Modules:

- Modules provide extended functionality.
- A module is a whitelisted contract capable of executing transactions on behalf of the smart contract wallet.
- Modules enhance the functionality of the contracts by adding extra access logic for transaction execution.

3. Hooks:

- A hook is essentially a function or a set of functions that are called at specific points within a contract's execution flow.
- Hooks can be set up to perform additional checks on transactions before they're executed.

## Repository Structure

All contracts are held within the `soul-wallet-contract/contracts` folder.

```
contracts
├── abstract
├── dev
│   └── tokens
├── factory
├── hooks
│   └── 2fa
├── interfaces
├── keystore
│   ├── L1
│   │   ├── base
│   │   └── interfaces
│   └── interfaces
├── libraries
├── modules
│   ├── interfaces
│   ├── keystore
│   │   ├── arbitrum
│   │   ├── base
│   │   ├── interfaces
│   │   └── optimism
│   ├── securityControlModule
│   │   └── trustedContractManager
│   │       ├── trustedHookManager
│   │       ├── trustedModuleManager
│   │       └── trustedValidatorManager
│   └── upgrade
├── paymaster
│   └── interfaces
├── proxy
└── validator
    └── libraries
```

## Test

```shell
npm run test
```

## Integration

Third parties can build new modules/plugins on top of SoulWallet to add additional functionality.

### Module

To add a new module, the contract should inherit from BaseModule. BaseModule is an abstract base contract that provides a foundation for other modules. It ensures the initialization, de-initialization, and proper authorization of modules.

```solidity
import "./BaseModule.sol";

contract NewModule is BaseModule {
    function requiredFunctions() external pure override returns (bytes4[] memory)
    {
        // return wallet functions that modules need access to
    }

     function inited(address wallet) internal view virtual override returns (bool) {
        // Implement your checking logic
    }

    function _init(bytes calldata data) internal virtual override {
        // Implement initialization logic
    }

    function _deInit() internal virtual override {
        // Implement de-initialization logic
    }
}

```

### Hook

o integrate a new hook, your contract should inherit `IHook` interface. This interface will define the standard structure and functionalities for your hooks.

```solidity

import {IHook} from "@soulwallet-core/contracts/interface/IHook.sol";

contract NewHook is IHook {
     function preIsValidSignatureHook(bytes32 hash, bytes calldata hookSignature) external view {
        // Implement hook logic
     }


    function preUserOpValidationHook(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds,
        bytes calldata hookSignature
    ) external {
        // Implement your hook-specific logic here
    }
}
```

## Disclaimer

This project is provided "as is" with no warranties or guarantees of any kind, express or implied. The developers make no claims about the suitability, reliability, availability, timeliness, security or accuracy of the software or its related documentation. The use of this software is at your own risk.

The developers will not be liable for any damages or losses, whether direct, indirect, incidental or consequential, arising from the use of or inability to use this software or its related documentation, even if advised of the possibility of such damages.

## Acknowledgments

- <a href='https://eips.ethereum.org/EIPS/eip-4337'>ERC-4337: Account Abstraction Using Alt Mempool</a>
- <a href='https://github.com/eth-infinitism/account-abstraction'>Infinitism account abstraction contract</a>
- <a href='https://github.com/safe-global/safe-contracts'>Gnosis Safe Contracts</a>
