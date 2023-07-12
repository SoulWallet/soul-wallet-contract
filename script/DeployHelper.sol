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
    Anvil
}

contract DeployHelper {
    address internal constant SINGLE_USE_FACTORY_ADDRESS = 0xBb6e024b9cFFACB947A71991E386681B1Cd1477D;
    ISingletonFactory internal constant SINGLETON_FACTORY =
        ISingletonFactory(0xce0042B868300000d44A59004Da54A005ffdcf9f);
    bytes32 internal constant DEFAULT_SALT = bytes32(uint256(0x1));
    address internal constant EMPTY_ADDRESS = 0x0000000000000000000000000000000000000000;
    bytes emptyBytes;

    function deploy(string memory name, bytes memory initCode) internal returns (address) {
        return deploy(name, DEFAULT_SALT, initCode);
    }

    function deploy(string memory name, bytes32 salt, bytes memory initCode) internal returns (address) {
        bytes32 initCodeHash = keccak256(initCode);
        address calculatedAddress = address(
            uint160(uint256(keccak256(abi.encodePacked(hex"ff", address(SINGLETON_FACTORY), salt, initCodeHash))))
        );
        address acutalAddress = SINGLETON_FACTORY.deploy(initCode, salt);
        require(calculatedAddress == acutalAddress, "create2 address mismatch");
        console.log(pad("Deploying", 10), pad(name, 33), pad(LibString.toHexString(acutalAddress), 63));
        return acutalAddress;
    }

    function pad(string memory name, uint256 n) internal pure returns (string memory) {
        string memory padded = name;
        while (bytes(padded).length < n) {
            padded = string.concat(padded, " ");
        }
        return padded;
    }

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
        }
    }
}
