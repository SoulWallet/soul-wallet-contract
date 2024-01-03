# SoulWalletCore

SoulWalletCore is a flexible and reusable smart contract wallet framework compliant with the EIP-4337 standard. It aims to provide a simple, adaptable, and easily integrable foundation for various wallet functionalities and extensions.

## ⚠️ Disclaimer

**The SoulWalletCore has not been audited and is provided as-is. It is not recommended for use in production environments.** Users and developers should exercise caution and use at their own risk.

## Features

- **EIP-4337 Compliant**: Ensures alignment with the latest developments in the Ethereum community.
- **Modular Design**: Facilitates easy addition or removal of features by developers according to their needs.
- **Reusability**: Designed for easy reuse across different projects.
- **Wallet Implementation Examples**: Includes multiple wallet examples based on SoulWalletCore to help developers get started quickly.

## Directory Structure

- `contracts/` - Contains all contract codes.
  - `base/` - Base contracts providing core functionalities.
  - `interface/` - Definitions of contract interfaces.
  - `snippets/` - Reusable code snippets.
  - `utils/` - Utility and helper contracts.
  - `validators/` - Contracts related to validators.
- `examples/` - Examples of wallets developed based on SoulWalletCore.

## Getting Started

To start using SoulWalletCore, clone the repository:

```sh
git clone https://github.com/SoulWallet/SoulWalletCore.git
cd SoulWalletCore
```

Next, choose or modify the contract examples as per your requirements.

## Example Usage

Refer to the examples in the `examples/` directory to understand how to build custom wallets based on SoulWalletCore.

- [BasicModularAccount](examples/BasicModularAccount.sol): A basic example of a modular account.
- [CustomAccessModularAccount](examples/CustomAccessModularAccount.sol): An example with custom permission.
- [AddFunctionDemo](examples/AddFunctionDemo/): An implementation example with a custom function added.
- [ModularAccountWithBuildinEOAValidator](examples/ModularAccountWithBuildinEOAValidator.sol): An example of a modular account with built-in EOA signature validation.
- [UpgradableModularAccount](examples/UpgradableModularAccount.sol): An example of an upgradable modular account.
  - Note: Due to the flexibility in implementing upgradable contracts, it is not implemented in SoulWalletCore. However, you can refer to this example.

## Contributions

We welcome contributions in any form, be it feature enhancements, bug reports, or documentation updates. Please submit pull requests or issues through GitHub.

## License

This project is licensed under the [GPL-3.0 License](LICENSE)

### License Clarification

This project makes use of code from the [eth-infinitism/account-abstraction](https://github.com/eth-infinitism/account-abstraction) repository, which is licensed under the GPL-3.0 license. However, all code developed for this project is based on the MIT license.

#### Using Our Code in Non-GPL-3.0 Projects

If you intend to use our code in projects that are not licensed under GPL-3.0, you can directly copy the files that are independently licensed under MIT from our repository into your project. This approach ensures compliance with the MIT license, provided that the copied files are standalone and do not depend on any GPL-3.0 licensed code from our project.

Please be aware that while you are free to use, modify, and distribute these MIT-licensed files, the GPL-3.0 licensed code from the eth-infinitism/account-abstraction repository may impose certain restrictions if used in your projects. It is important to ensure that your use of these files adheres to the respective license terms.
