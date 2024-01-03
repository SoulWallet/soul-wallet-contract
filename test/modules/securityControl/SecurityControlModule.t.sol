// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../..//soulwallet/base/SoulWalletInstence.sol";
import "@source/modules/securityControlModule/trustedContractManager/trustedModuleManager/TrustedModuleManager.sol";
import "@source/modules/securityControlModule/trustedContractManager/trustedHookManager/TrustedHookManager.sol";
import
    "@source/modules/securityControlModule/trustedContractManager/trustedValidatorManager/TrustedValidatorManager.sol";
import "@source/modules/securityControlModule/SecurityControlModule.sol";
import "../../helper/Bundler.t.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@source/dev/Tokens/TokenERC20.sol";
import "@source/libraries/TypeConversion.sol";
import "../../helper/UserOpHelper.t.sol";
import "@source/dev/NewImplementation.sol";
import "@source/modules/upgrade/UpgradeModule.sol";
import {Crypto2FAHook} from "@source/hooks/2fa/Crypto2FAHook.sol";

contract SecurityControlModuleTest is Test, UserOpHelper {
    using ECDSA for bytes32;
    using TypeConversion for address;

    SoulWalletInstence public soulWalletInstence;
    ISoulWallet public soulWallet;
    SecurityControlModule public securityControlModule;
    TrustedModuleManager public trustedModuleManager;
    TrustedHookManager public trustedHookManager;
    TrustedValidatorManager public trustedValidatorManager;
    UpgradeModule public upgradeModule;
    Crypto2FAHook public crypto2FAHook;

    uint64 public time = 2 days;
    address public walletOwner;
    address trustedManagerOwner;
    uint256 public walletOwnerPrivateKey;
    Bundler public bundler;
    TokenERC20 public token;

    address public wallet2faOwner;
    uint256 public wallet2faOwnerPrivateKey;

    function setUp() public {
        (walletOwner, walletOwnerPrivateKey) = makeAddrAndKey("owner");

        (trustedManagerOwner,) = makeAddrAndKey("trustedManagerOwner");
        address newImplementation = address(new NewImplementation());
        upgradeModule = new UpgradeModule(newImplementation);
        (wallet2faOwner, wallet2faOwnerPrivateKey) = makeAddrAndKey("2fa");
        crypto2FAHook = new Crypto2FAHook();

        trustedModuleManager = new TrustedModuleManager(
            trustedManagerOwner
        );
        trustedHookManager = new TrustedHookManager(
            trustedManagerOwner
        );
        trustedValidatorManager = new TrustedValidatorManager(
                trustedManagerOwner
            );
        securityControlModule = new SecurityControlModule(
            trustedModuleManager,
            trustedHookManager,
            trustedValidatorManager
        );

        bytes[] memory modules = new bytes[](1);
        modules[0] = abi.encodePacked(securityControlModule, abi.encode(time));
        bytes[] memory hooks = new bytes[](0);
        bytes32 salt = bytes32(0);
        bytes32[] memory owners = new bytes32[](1);
        owners[0] = walletOwner.toBytes32();

        soulWalletInstence = new SoulWalletInstence(address(0), owners,  modules, hooks,  salt);
        soulWallet = soulWalletInstence.soulWallet();

        (address[] memory _modules, bytes4[][] memory _selectors) = soulWallet.listModule();
        assertEq(_modules.length, 1, "module length error");
        assertEq(_selectors.length, 1, "selector length error");
        assertEq(_modules[0], address(securityControlModule), "module address error");
        assertEq(_selectors[0].length, 6);
        assertEq(_selectors[0][5], bytes4(keccak256("installModule(bytes)")), "addModule selector error");
        assertEq(_selectors[0][4], bytes4(keccak256("uninstallModule(address)")), "uninstallModule selector error");
        assertEq(_selectors[0][3], bytes4(keccak256("installHook(bytes,uint8)")), "installHook selector error");
        assertEq(_selectors[0][2], bytes4(keccak256("uninstallHook(address)")), "uninstallHook selector error");
        assertEq(_selectors[0][1], bytes4(keccak256("installValidator(bytes)")), "installValidator selector error");
        assertEq(
            _selectors[0][0], bytes4(keccak256("uninstallValidator(address)")), "uninstallValidator selector error"
        );

        bundler = new Bundler();
        token = new TokenERC20(18);
    }

    // #region Module

    //function queue(address _target, bytes calldata _data) external returns (bytes32);
    function addModule_queue() private returns (bytes32) {
        bytes memory initData;
        return securityControlModule.queue(
            address(soulWallet),
            abi.encodeWithSelector(
                bytes4(keccak256("installModule(bytes)")), abi.encodePacked(address(upgradeModule), initData)
            )
        );
    }

    // //function cancel(bytes32 _txId) external;
    function addModule_cancel(bytes32 _txId) private {
        securityControlModule.cancel(_txId);
    }

    // //function cancelAll() external;
    function addModule_cancelAll() private {
        securityControlModule.cancelAll(address(soulWallet));
    }

    // //function execute(address _target, bytes calldata _data) external  ;
    function addModule_execute() private {
        bytes memory initData;
        securityControlModule.execute(
            address(soulWallet),
            abi.encodeWithSelector(
                bytes4(keccak256("installModule(bytes)")), abi.encodePacked(address(upgradeModule), initData)
            )
        );
    }

    function test_addModule_withoutWhiteList() public {
        {
            vm.startPrank(address(0x1111));

            vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("NotOwnerError()"))));
            addModule_queue();

            vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("NotOwnerError()"))));
            addModule_execute();

            vm.stopPrank();
        }

        {
            vm.startPrank(walletOwner);
            bytes32 txId = addModule_queue();
            vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("AlreadyQueuedError(bytes32)")), txId));
            addModule_queue();
            vm.stopPrank();

            vm.prank(address(0x1111));
            vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("NotOwnerError()"))));
            addModule_cancel(txId);

            vm.prank(address(0x1111));
            vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("NotOwnerError()"))));
            addModule_cancelAll();
            {
                vm.startPrank(walletOwner);
                {
                    uint256 snapshotId = vm.snapshot();
                    addModule_cancel(txId);
                    vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("NotQueuedError(bytes32)")), txId));
                    addModule_execute();
                    vm.revertTo(snapshotId);
                }
                {
                    uint256 snapshotId = vm.snapshot();
                    addModule_cancelAll();
                    bytes memory initData;
                    SecurityControlModule.WalletConfig memory walletConfig =
                        securityControlModule.getWalletConfig(address(soulWallet));
                    bytes32 _txId = securityControlModule.getTxId(
                        walletConfig.seed,
                        address(soulWallet),
                        abi.encodeWithSelector(
                            bytes4(keccak256("installModule(bytes)")),
                            abi.encodePacked(address(upgradeModule), initData)
                        )
                    );
                    vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("NotQueuedError(bytes32)")), _txId));
                    addModule_execute();
                    vm.revertTo(snapshotId);
                }
                vm.stopPrank();
            }
            vm.startPrank(walletOwner);
            vm.expectRevert();
            addModule_execute();
            vm.stopPrank();

            vm.warp(block.timestamp + time);

            vm.prank(address(0x1111));
            vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("NotOwnerError()"))));
            addModule_execute();

            vm.prank(walletOwner);
            addModule_execute();

            (address[] memory _modules,) = soulWallet.listModule();
            assertEq(_modules.length, 2, "module length error");

            assertEq(_modules[0], address(upgradeModule), "module address error");

            upgradeModule.upgrade(address(soulWallet));
            (bool success, bytes memory result) =
                address(soulWallet).staticcall(abi.encodeWithSelector(NewImplementation.hello.selector));
            require(success, "call failed");
            assertEq(abi.decode(result, (string)), "hello world");
        }
    }

    event initEvent(address wallet);
    event deInitEvent(address wallet);

    function test_addModule() public {
        vm.startPrank(trustedManagerOwner);
        address[] memory _modules = new address[](1);
        _modules[0] = address(upgradeModule);
        trustedModuleManager.add(_modules);
        vm.stopPrank();

        vm.startPrank(walletOwner);
        addModule_execute();
        vm.stopPrank();

        (address[] memory modules,) = soulWallet.listModule();
        assertEq(modules.length, 2, "module length error");

        assertEq(modules[0], address(upgradeModule), "module address error");
    }

    //function queue(address _target, bytes calldata _data) external returns (bytes32);
    function removeModule_queue() private returns (bytes32) {
        bytes memory _data =
            abi.encodeWithSelector(bytes4(keccak256("uninstallModule(address)")), address(upgradeModule));

        return securityControlModule.queue(address(soulWallet), _data);
    }

    //function cancel(bytes32 _txId) external;
    function removeModule_cancel(bytes32 _txId) private {
        securityControlModule.cancel(_txId);
    }

    //function cancelAll() external;
    function removeModule_cancelAll() private {
        securityControlModule.cancelAll(address(soulWallet));
    }

    //function execute(address _target, bytes calldata _data) external  ;
    function removeModule_execute() private {
        securityControlModule.execute(
            address(soulWallet),
            abi.encodeWithSelector(bytes4(keccak256("uninstallModule(address)")), address(upgradeModule))
        );
    }

    function test_removeModule() public {
        test_addModule();

        vm.startPrank(walletOwner);
        removeModule_queue();
        vm.expectRevert();
        removeModule_execute();

        vm.warp(block.timestamp + time);
        removeModule_execute();

        vm.expectRevert();
        upgradeModule.upgrade(address(soulWallet));
        vm.expectRevert();
        (bool success,) = address(soulWallet).staticcall(abi.encodeWithSelector(NewImplementation.hello.selector));
        assertEq(success, false);

        vm.stopPrank();

        (address[] memory _modules,) = soulWallet.listModule();
        assertEq(_modules.length, 1, "module length error");
    }

    // #endregion

    // #region Hook

    //function queue(address _target, bytes calldata _data) external returns (bytes32);
    function addHook_queue() private returns (bytes32) {
        uint8 capabilityFlags = 3;
        bytes memory initData = abi.encodePacked(address(wallet2faOwner));
        return securityControlModule.queue(
            address(soulWallet),
            abi.encodeWithSelector(
                bytes4(keccak256("installHook(bytes,uint8)")),
                abi.encodePacked(address(crypto2FAHook), initData, capabilityFlags)
            )
        );
    }

    //function execute(address _target, bytes calldata _data) external  ;
    function addHook_execute() private {
        uint8 capabilityFlags = 3;
        bytes memory initData = abi.encodePacked(address(wallet2faOwner));
        securityControlModule.execute(
            address(soulWallet),
            abi.encodeWithSelector(
                bytes4(keccak256("installHook(bytes,uint8)")),
                abi.encodePacked(address(crypto2FAHook), initData, capabilityFlags)
            )
        );
    }

    function test_addHook() public {
        vm.startPrank(trustedManagerOwner);
        address[] memory _hooks = new address[](1);
        _hooks[0] = address(crypto2FAHook);
        trustedHookManager.add(_hooks);
        vm.stopPrank();

        vm.startPrank(walletOwner);
        addHook_execute();
        vm.stopPrank();
    }

    function test_addHook_withoutWhiteList() public {
        vm.startPrank(walletOwner);

        vm.expectRevert();
        addHook_execute();

        addHook_queue();

        vm.expectRevert();
        addHook_execute();

        vm.warp(block.timestamp + time);
        addHook_execute();

        vm.stopPrank();
    }

    // #endregion
}
