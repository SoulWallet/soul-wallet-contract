// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../soulwallet/base/SoulWalletInstence.sol";
import "@source/modules/upgrade/UpgradeModule.sol";
import "@source/dev/NewImplementation.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract UpgradeTest is Test {
    using TypeConversion for address;
    using ECDSA for bytes32;

    SoulWalletInstence public soulWalletInstence;
    ISoulWallet public soulWallet;
    address public walletOwner;
    uint256 public walletOwnerPrivateKey;
    UpgradeModule public upgradeModule;
    address public newImplementation;

    function setUp() public {
        (walletOwner, walletOwnerPrivateKey) = makeAddrAndKey("owner");
        newImplementation = address(new NewImplementation());
        upgradeModule = new UpgradeModule(newImplementation);

        bytes[] memory modules = new bytes[](1);
        bytes memory upgradeModule_initData;
        modules[0] = abi.encodePacked(address(upgradeModule), upgradeModule_initData);
        bytes[] memory hooks = new bytes[](0);

        bytes32[] memory owners = new bytes32[](1);
        owners[0] = walletOwner.toBytes32();

        bytes32 salt = bytes32(0);
        soulWalletInstence = new SoulWalletInstence(address(0), owners,  modules, hooks,  salt);
        soulWallet = soulWalletInstence.soulWallet();

        (address[] memory _modules, bytes4[][] memory _selectors) = soulWallet.listModule();
        assertEq(_modules.length, 1, "module length error");
        assertEq(_selectors.length, 1, "selector length error");
        assertEq(_modules[0], address(upgradeModule), "module address error");
        assertEq(_selectors[0].length, 1);
        assertEq(_selectors[0][0], bytes4(keccak256("upgradeTo(address)")), "upgradeTo selector error");
    }

    function test_upgrade() public {
        bytes32 _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

        bytes32 _oldImplementation = vm.load(address(soulWallet), _IMPLEMENTATION_SLOT);
        address oldImplementation;
        assembly {
            oldImplementation := _oldImplementation
        }
        upgradeModule.upgrade(address(soulWallet));

        // test new implementation
        (bool success, bytes memory result) =
            address(soulWallet).staticcall(abi.encodeWithSelector(NewImplementation.hello.selector));
        require(success, "call failed");
        assertEq(abi.decode(result, (string)), "hello world");
    }
}
