// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {LibString} from "@solady/src/utils/LibString.sol";

interface ISingletonFactory {
    function deploy(bytes memory _initCode, bytes32 _salt) external returns (address payable createdContract);
}

enum Network {
    Mainnet,
    Ropsten,
    Rinkeby,
    Goerli,
    Kovan,
    Optimism,
    Arbitrum,
    ArbitrumGoerli,
    OptimismGoerli,
    Anvil,
    Sepolia,
    ArbitrumSepolia,
    OptimismSepolia,
    ScrollSepolia,
    BaseSepolia,
    Scroll
}

library NetWorkLib {
    function getNetwork() internal view returns (Network network) {
        if (block.chainid == 1) {
            return Network.Mainnet;
        } else if (block.chainid == 3) {
            return Network.Ropsten;
        } else if (block.chainid == 4) {
            return Network.Rinkeby;
        } else if (block.chainid == 5) {
            return Network.Goerli;
        } else if (block.chainid == 42) {
            return Network.Kovan;
        } else if (block.chainid == 10) {
            return Network.Optimism;
        } else if (block.chainid == 42161) {
            return Network.Arbitrum;
        } else if (block.chainid == 31337) {
            return Network.Anvil;
        } else if (block.chainid == 420) {
            return Network.OptimismGoerli;
        } else if (block.chainid == 421613) {
            return Network.ArbitrumGoerli;
        } else if (block.chainid == 11155111) {
            return Network.Sepolia;
        } else if (block.chainid == 421614) {
            return Network.ArbitrumSepolia;
        } else if (block.chainid == 11155420) {
            return Network.OptimismSepolia;
        } else if (block.chainid == 534352) {
            return Network.Scroll;
        } else if (block.chainid == 534351) {
            return Network.ScrollSepolia;
        } else if (block.chainid == 84532) {
            return Network.BaseSepolia;
        } else {
            revert("unsupported network");
        }
    }

    function getNetworkName() internal view returns (string memory) {
        if (block.chainid == 1) {
            return "Mainnet";
        } else if (block.chainid == 3) {
            return "Ropsten";
        } else if (block.chainid == 4) {
            return "Rinkeby";
        } else if (block.chainid == 5) {
            return "Goerli";
        } else if (block.chainid == 42) {
            return "Kovan";
        } else if (block.chainid == 10) {
            return "Optimism";
        } else if (block.chainid == 42161) {
            return "Arbitrum";
        } else if (block.chainid == 31337) {
            return "Anvil";
        } else if (block.chainid == 420) {
            return "OptimismGoerli";
        } else if (block.chainid == 421613) {
            return "ArbitrumGoerli";
        } else if (block.chainid == 11155111) {
            return "Sepolia";
        } else if (block.chainid == 421614) {
            return "ArbitrumSepolia";
        } else if (block.chainid == 11155420) {
            return "OptimismSepolia";
        } else if (block.chainid == 534351) {
            return "ScrollSepolia";
        } else if (block.chainid == 534352) {
            return "Scroll";
        } else if (block.chainid == 84532) {
            return "BaseSepolia";
        } else {
            revert("unsupported network");
        }
    }
}

abstract contract DeployHelper is Script {
    address deployer;
    uint256 privateKey;
    address internal constant SINGLE_USE_FACTORY_ADDRESS = 0xBb6e024b9cFFACB947A71991E386681B1Cd1477D;
    ISingletonFactory internal constant SINGLETON_FACTORY =
        ISingletonFactory(0xce0042B868300000d44A59004Da54A005ffdcf9f);
    bytes32 internal constant DEFAULT_SALT = bytes32(uint256(0x1));
    address internal constant EMPTY_ADDRESS = 0x0000000000000000000000000000000000000000;
    bytes emptyBytes;
    address internal ENTRYPOINT_ADDRESS = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    function deploy(string memory name, bytes memory initCode) internal returns (address) {
        return deploy(name, DEFAULT_SALT, initCode);
    }

    constructor() {
        privateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        require(privateKey != 0, "DEPLOYER_PRIVATE_KEY not provided");
        deployer = vm.addr(privateKey);
        console.log("deployer address", deployer);
    }

    function deploy(string memory name, bytes32 salt, bytes memory initCode) internal returns (address) {
        bytes32 initCodeHash = keccak256(initCode);
        address calculatedAddress = address(
            uint160(uint256(keccak256(abi.encodePacked(hex"ff", address(SINGLETON_FACTORY), salt, initCodeHash))))
        );
        if (calculatedAddress.code.length == 0) {
            address acutalAddress = SINGLETON_FACTORY.deploy(initCode, salt);
            require(calculatedAddress == acutalAddress, "create2 address mismatch");
            console.log(pad("Deploying", 10), pad(name, 33), pad(LibString.toHexString(acutalAddress), 63));
        } else {
            console.log(pad("Finding", 10), pad(name, 33), pad(LibString.toHexString(calculatedAddress), 63));
        }
        writeAddressToEnvBackend(name, calculatedAddress);

        return calculatedAddress;
    }

    function pad(string memory name, uint256 n) internal pure returns (string memory) {
        string memory padded = name;
        while (bytes(padded).length < n) {
            padded = string.concat(padded, " ");
        }
        return padded;
    }

    function getNetwork() internal view returns (Network network) {
        return NetWorkLib.getNetwork();
    }

    function getNetworkName() internal view returns (string memory) {
        return NetWorkLib.getNetworkName();
    }

    function deploySingletonFactory() internal {
        if (address(SINGLETON_FACTORY).code.length == 0) {
            console.log("send 1 eth to SINGLE_USE_FACTORY_ADDRESS");
            string[] memory sendEthInputs = new string[](7);
            sendEthInputs[0] = "cast";
            sendEthInputs[1] = "send";
            sendEthInputs[2] = "--private-key";
            sendEthInputs[3] = LibString.toHexString(privateKey);
            sendEthInputs[4] = LibString.toHexString(SINGLE_USE_FACTORY_ADDRESS);
            sendEthInputs[5] = "--value";
            sendEthInputs[6] = "1ether";
            vm.ffi(sendEthInputs);
            console.log("deploy singleton factory");
            string[] memory inputs = new string[](3);
            inputs[0] = "cast";
            inputs[1] = "publish";
            inputs[2] =
                "0xf9016c8085174876e8008303c4d88080b90154608060405234801561001057600080fd5b50610134806100206000396000f3fe6080604052348015600f57600080fd5b506004361060285760003560e01c80634af63f0214602d575b600080fd5b60cf60048036036040811015604157600080fd5b810190602081018135640100000000811115605b57600080fd5b820183602082011115606c57600080fd5b80359060200191846001830284011164010000000083111715608d57600080fd5b91908080601f016020809104026020016040519081016040528093929190818152602001838380828437600092019190915250929550509135925060eb915050565b604080516001600160a01b039092168252519081900360200190f35b6000818351602085016000f5939250505056fea26469706673582212206b44f8a82cb6b156bfcc3dc6aadd6df4eefd204bc928a4397fd15dacf6d5320564736f6c634300060200331b83247000822470";
            vm.ffi(inputs);
        }
    }

    function writeAddressToEnv(string memory label, address addr) internal {
        string[] memory inputs = new string[](4);
        inputs[0] = "node";
        inputs[1] = "script/ffi/save_to_env.js";
        inputs[2] = label;
        inputs[3] = vm.toString(addr);
        vm.ffi(inputs);
    }

    function writeAddressToEnvBackend(string memory label, address addr) internal {
        string[] memory inputs = new string[](4);
        inputs[0] = "node";
        inputs[1] = "script/ffi/save_to_env_backend.js";
        inputs[2] = label;
        inputs[3] = vm.toString(addr);
        vm.ffi(inputs);
    }

    function getCreateAddress(address _origin, uint256 _nonce) public pure returns (address) {
        bytes memory data;
        if (_nonce == 0x00) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), _origin, bytes1(0x80));
        } else if (_nonce <= 0x7f) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), _origin, uint8(_nonce));
        } else if (_nonce <= 0xff) {
            data = abi.encodePacked(bytes1(0xd7), bytes1(0x94), _origin, bytes1(0x81), uint8(_nonce));
        } else if (_nonce <= 0xffff) {
            data = abi.encodePacked(bytes1(0xd8), bytes1(0x94), _origin, bytes1(0x82), uint16(_nonce));
        } else if (_nonce <= 0xffffff) {
            data = abi.encodePacked(bytes1(0xd9), bytes1(0x94), _origin, bytes1(0x83), uint24(_nonce));
        } else {
            data = abi.encodePacked(bytes1(0xda), bytes1(0x94), _origin, bytes1(0x84), uint32(_nonce));
        }
        return address(uint160(uint256(keccak256(data))));
    }
}
