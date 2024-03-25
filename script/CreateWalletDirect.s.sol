// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@source/factory/SoulWalletFactory.sol";
import "./DeployHelper.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {NetWorkLib} from "./DeployHelper.sol";
import "@source/libraries/TypeConversion.sol";
import {Solenv} from "@solenv/Solenv.sol";

contract CreateWalletDirect is Script {
    using MessageHashUtils for bytes32;
    using TypeConversion for address;

    uint256 guardianThreshold = 1;
    uint64 initialGuardianSafePeriod = 2 days;

    address walletSigner;
    uint256 walletSingerPrivateKey;

    address newWalletSigner;
    uint256 newWalletSingerPrivateKey;

    address guardianAddress;
    uint256 guardianPrivateKey;

    address securityControlModuleAddress;

    address keystoreModuleAddress;

    address defaultCallbackHandler;

    SoulWalletFactory soulwalletFactory;

    address payable soulwalletAddress;

    bytes32 private constant _TYPE_HASH_SET_KEY =
        keccak256("SetKey(bytes32 keyStoreSlot,uint256 nonce,bytes32 newSigner)");
    bytes32 private constant _TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 private DOMAIN_SEPARATOR;

    function run() public {
        Solenv.config(".env_backend");
        // wallet signer info
        walletSingerPrivateKey = vm.envUint("WALLET_SIGNGER_PRIVATE_KEY");
        walletSigner = vm.addr(walletSingerPrivateKey);
        // guardian info
        guardianPrivateKey = vm.envUint("GUARDIAN_PRIVATE_KEY");
        guardianAddress = vm.addr(guardianPrivateKey);

        vm.startBroadcast(walletSingerPrivateKey);
        string memory networkName = NetWorkLib.getNetworkName();
        console.log("create wallet on ", networkName);
        createWallet();
    }

    function createWallet() private {
        bytes32 salt = bytes32(0);
        bytes[] memory modules = new bytes[](0);
        bytes32[] memory owners = new bytes32[](1);
        owners[0] = walletSigner.toBytes32();

        bytes[] memory hooks = new bytes[](0);

        defaultCallbackHandler = loadEnvContract("DefaultCallbackHandler");
        bytes memory initializer = abi.encodeWithSignature(
            "initialize(bytes32[],address,bytes[],bytes[])", owners, defaultCallbackHandler, modules, hooks
        );
        soulwalletFactory = SoulWalletFactory(loadEnvContract("SoulwalletFactory"));
        address cacluatedAddress = soulwalletFactory.getWalletAddress(initializer, salt);

        soulwalletAddress = payable(soulwalletFactory.createWallet(initializer, salt));
        require(cacluatedAddress == soulwalletAddress, "calculated address not match");
        console.log("wallet address: ", soulwalletAddress);
    }

    function loadEnvContract(string memory label) private view returns (address) {
        address contractAddress = vm.envAddress(label);
        require(contractAddress != address(0), string(abi.encodePacked(label, " not provided")));
        require(contractAddress.code.length > 0, string(abi.encodePacked(label, " needs be deployed")));
        return contractAddress;
    }
}
