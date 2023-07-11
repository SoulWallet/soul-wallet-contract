// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@source/modules/keystore/OptimismKeyStoreProofModule/OpKnownStateRootWithHistory.sol";
import "@source/modules/keystore/KeystoreProof.sol";
import "@source/modules/keystore/OptimismKeyStoreProofModule/IL1Block.sol";

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

contract L2KeystoreDeployer is Script {
    address l2Deployer;
    address private constant OP_L1_BLOCK_ADDRESS = 0x4200000000000000000000000000000000000015;
    bytes32 private constant DEFAULT_SALT = bytes32(uint256(0x1));

    function run() public {
        uint256 privateKey = vm.envUint("L2_DEPLOYER_PRIVATE_KEY");
        l2Deployer = vm.addr(privateKey);
        vm.broadcast(privateKey);
        Network network = getNetwork();
        if (network == Network.Mainnet) {
            console.log("deploy l2keystore contract on mainnet");
        } else if (network == Network.Arbitrum) {
            console.log("deploy l2keystore contract on Arbitrum");
        } else if (network == Network.Optimism) {
            console.log("deploy l2keystore contract on Optimism");
        } else if (network == Network.Anvil) {
            console.log("deploy l2keystore contract on Anvil");
            AnvilDeploy();
        }
    }

    function AnvilDeploy() private {
        OpKnownStateRootWithHistory knownStateRootWithHistory =
            new OpKnownStateRootWithHistory{salt: 0}(OP_L1_BLOCK_ADDRESS);
        console.log("OpKnownStateRootWithHistory ->", address(knownStateRootWithHistory));
    }

    function opDeploy() private {
        OpKnownStateRootWithHistory knownStateRootWithHistory =
            new OpKnownStateRootWithHistory{salt: 0}(OP_L1_BLOCK_ADDRESS);
        console.log("OpKnownStateRootWithHistory ->", address(knownStateRootWithHistory));
    }

    function getNetwork() private view returns (Network network) {
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

    function deploy(string memory name, bytes memory initCode) internal returns (address) {
        return deploy(name, DEFAULT_SALT, initCode);
    }

    function deploy(string memory name, bytes32 salt, bytes memory initCode) internal returns (address) {
        bytes32 initCodeHash = keccak256(initCode);
        address deploymentAddress = address(
            uint160(
                uint256(keccak256(abi.encodePacked(hex"ff", address(IMMUTABLE_CREATE2_FACTORY), salt, initCodeHash)))
            )
        );
        bool deploying;
        if (!IMMUTABLE_CREATE2_FACTORY.hasBeenDeployed(deploymentAddress)) {
            deploymentAddress = IMMUTABLE_CREATE2_FACTORY.safeCreate2(salt, initCode);
            deploying = true;
        }
        console.log(
            pad(deploying ? "Deploying" : "Found", 10),
            pad(name, 23),
            pad(LibString.toHexString(deploymentAddress), 43),
            LibString.toHexString(uint256(initCodeHash))
        );
        return deploymentAddress;
    }

    function pad(string memory name, uint256 n) internal pure returns (string memory) {
        string memory padded = name;
        while (bytes(padded).length < n) {
            padded = string.concat(padded, " ");
        }
        return padded;
    }
}
