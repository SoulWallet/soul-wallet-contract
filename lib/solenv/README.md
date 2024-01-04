# <h1 align="center"> solenv </h1>

**Load .env files in Solidity scripts/tests**

![Github Actions](https://github.com/memester-xyz/solenv/workflows/test/badge.svg)

# ⚠️ Note ⚠️
[Foundry recently shipped default dotenv parsing](https://github.com/foundry-rs/foundry/pull/2587). It's in active development but soon the solenv library will no longer be needed. Yay for upstreaming!

## Installation

```
forge install memester-xyz/solenv
```

## Usage

Firstly, it's very important that you do not commit your `.env` file. It should go without saying but make sure to add it to your `.gitignore` file! This repo has committed the `.env` and `.env.test` files only for examples and tests.

1. Add this import to your script or test:
```solidity
import {Solenv} from "solenv/Solenv.sol";
```

2. Call `.config()` somewhere. It defaults to using `.env` in your project root, but you can pass another string as a parameter to load another file in instead.
```solidity
// Inside a test
function setUp() public {
    Solenv.config();
}

// Inside a script, load a file with a different name
function run() public {
    Solenv.config(".env.prod");

    // Continue with your script...
}
```

3. You can then use the [standard "env" cheatcodes](https://book.getfoundry.sh/cheatcodes/external.html) in order to read your variables. e.g. `envString`, `envUint`, `envBool`, etc.
```solidity
string memory apiKey = vm.envString("API_KEY");
uint256 retries = vm.envUint("RETRIES");
bool ouputLogs = vm.envBool("OUTPUT_LOGS");
```

4. You must enable [ffi](https://book.getfoundry.sh/cheatcodes/ffi.html) in order to use the library. You can either pass the `--ffi` flag to any forge commands you run (e.g. `forge script Script --ffi`), or you can add `ffi = true` to your `foundry.toml` file.

### Notes

 - Comments start with `#` and must be on a newline
 - If you set a key twice, the last value in the file is used
 - It assumes you are running on a UNIX based machine with `sh`, `cast` and `xxd` installed.

## Example

We have example usage for both [tests](./test/Solenv.t.sol) and [scripts](./script/Solenv.s.sol).

To see the script in action, you can run:
```
forge script SolenvScript
```

## Contributing

Clone this repo and run:

```
forge install
```

Make sure all tests pass, add new ones if needed:

```
forge test
```

## Why?

[Forge scripting](https://book.getfoundry.sh/tutorials/solidity-scripting.html) is becoming more popular. With solenv your scripts are even more powerful and natural to work with.

## Development

This project uses [Foundry](https://getfoundry.sh). See the [book](https://book.getfoundry.sh/getting-started/installation.html) for instructions on how to install and use Foundry.
