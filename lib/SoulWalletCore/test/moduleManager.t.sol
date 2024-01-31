// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {IModuleManager} from "../contracts/interface/IModuleManager.sol";
import {IOwnerManager} from "../contracts/interface/IOwnerManager.sol";
import {BasicModularAccount} from "../examples/BasicModularAccount.sol";
import {Execution} from "../contracts/interface/IStandardExecutor.sol";
import "../contracts/validators/EOAValidator.sol";
import {ReceiverHandler} from "./dev/ReceiverHandler.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {DeployEntryPoint} from "./dev/deployEntryPoint.sol";
import {SoulWalletFactory} from "./dev/SoulWalletFactory.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {TokenERC20} from "./dev/TokenERC20.sol";
import {DemoHook} from "./dev/demoHook.sol";
import {DemoModule} from "./dev/demoModule.sol";

interface _IModuleManager {
    function executeFromModule(address dest, uint256 value, bytes memory func) external returns (bytes memory);
}

contract ModuleManagerTest is Test {
    using MessageHashUtils for bytes32;

    SoulWalletFactory walletFactory;
    BasicModularAccount walletImpl;

    EOAValidator validator;
    ReceiverHandler _fallback;

    TokenERC20 token;
    DemoHook demoHook;
    DemoModule demoModule;

    address public walletOwner;
    uint256 public walletOwnerPrivateKey;

    BasicModularAccount wallet;

    function setUp() public {
        walletImpl = new BasicModularAccount(address(this));
        walletFactory = new SoulWalletFactory(address(walletImpl), address(this), address(this));
        validator = new EOAValidator();
        _fallback = new ReceiverHandler();
        (walletOwner, walletOwnerPrivateKey) = makeAddrAndKey("owner1");
        token = new TokenERC20();
        demoHook = new DemoHook();
        demoModule = new DemoModule();

        bytes32 salt = 0;
        bytes memory initializer;
        {
            bytes32 owner = bytes32(uint256(uint160(walletOwner)));
            bytes memory defaultValidator = abi.encodePacked(address(validator));
            address defaultFallback = address(_fallback);
            initializer = abi.encodeWithSelector(
                BasicModularAccount.initialize.selector, owner, defaultValidator, defaultFallback
            );
        }

        wallet = BasicModularAccount(payable(walletFactory.createWallet(initializer, salt)));
    }

    event InitCalled(bytes data);
    event DeInitCalled();

    error CALLER_MUST_BE_SELF_OR_MODULE();

    error MODULE_EXECUTE_FROM_MODULE_RECURSIVE();
    error CALLER_MUST_BE_AUTHORIZED_MODULE();

    function returndatademo() external pure returns (bytes memory) {
        return hex"1234";
    }

    function test_Module() public {
        bytes4[] memory _selectors = new bytes4[](2);
        _selectors[0] = IOwnerManager.addOwner.selector;
        _selectors[1] = IModuleManager.executeFromModule.selector;

        // function installModule(bytes calldata moduleAndData, bytes4[] calldata selectors) external;
        bytes memory moduleData = hex"aabbcc";
        bytes memory moduleAndData = abi.encodePacked(address(demoModule), moduleData);

        vm.startPrank(address(wallet));
        vm.expectEmit(true, true, true, true); //   (bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData).
        emit InitCalled(moduleData);
        wallet.installModule(moduleAndData, _selectors);
        assertTrue(wallet.isInstalledModule(address(demoModule)));
        vm.stopPrank();

        (address[] memory modules, bytes4[][] memory selectors) = wallet.listModule();
        assertEq(modules.length, 1);
        assertEq(modules[0], address(demoModule));
        assertEq(selectors.length, 1);
        assertEq(selectors[0].length, 2);
        assertEq(selectors[0][0], IModuleManager.executeFromModule.selector);
        assertEq(selectors[0][1], IOwnerManager.addOwner.selector);

        // CALLER_MUST_BE_SELF_OR_MODULE() error
        vm.expectRevert(CALLER_MUST_BE_SELF_OR_MODULE.selector);
        wallet.addOwner(bytes32(uint256(uint160(address(2)))));

        vm.prank(address(demoModule));
        wallet.addOwner(bytes32(uint256(uint160(address(2)))));

        // CALLER_MUST_BE_SELF_OR_MODULE() error
        vm.prank(address(demoModule));
        vm.expectRevert(CALLER_MUST_BE_SELF_OR_MODULE.selector);
        wallet.removeOwner(bytes32(uint256(uint160(address(2)))));

        vm.prank(address(wallet));
        wallet.removeOwner(bytes32(uint256(uint160(address(2)))));

        vm.startPrank(address(wallet));
        vm.expectEmit(true, true, true, true); //   (bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData).
        emit DeInitCalled();
        wallet.uninstallModule(address(demoModule));
        assertFalse(wallet.isInstalledModule(address(demoModule)));
        vm.stopPrank();

        {
            bytes4[] memory _selectors2 = new bytes4[](1);
            _selectors2[0] = IOwnerManager.addOwner.selector;
            vm.prank(address(wallet));
            wallet.installModule(moduleAndData, _selectors2);

            assertTrue(wallet.isInstalledModule(address(demoModule)));

            vm.startPrank(address(demoModule));
            // function executeFromModule(address dest, uint256 value, bytes memory func) external
            vm.expectRevert(CALLER_MUST_BE_AUTHORIZED_MODULE.selector);
            wallet.executeFromModule(address(wallet), 0, "");
            vm.stopPrank();
            vm.prank(address(wallet));
            wallet.uninstallModule(address(demoModule));
        }
        {
            vm.prank(address(wallet));
            wallet.installModule(moduleAndData, _selectors);

            assertTrue(wallet.isInstalledModule(address(demoModule)));

            vm.startPrank(address(demoModule));
            // function executeFromModule(address dest, uint256 value, bytes memory func) external
            vm.expectRevert(MODULE_EXECUTE_FROM_MODULE_RECURSIVE.selector);
            wallet.executeFromModule(address(wallet), 0, "");

            bytes memory func = abi.encodeWithSelector(this.returndatademo.selector);
            bytes memory returndata = _IModuleManager(address(wallet)).executeFromModule(address(this), 0, func);

            assertEq(returndata, hex"1234");

            vm.stopPrank();
        }
    }
}
