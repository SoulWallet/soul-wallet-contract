// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../base/SoulWalletInstence.sol";
import "@source/modules/SecurityControlModule/SecurityControlModule.sol";
import "@source/trustedContractManager/trustedModuleManager/TrustedModuleManager.sol";
import "@source/trustedContractManager/trustedPluginManager/TrustedPluginManager.sol";
import "@source/dev/DemoModule.sol";

contract SecurityControlModuleTest is Test {
    SoulWalletInstence public soulWalletInstence;
    ISoulWallet public soulWallet;
    SecurityControlModule public securityControlModule;
    TrustedModuleManager public trustedModuleManager;
    TrustedPluginManager public trustedPluginManager;
    DemoModule public demoModule;
    uint64 public time = 2 days;
    address public walletOwner;
    address trustedManagerOwner;

    function setUp() public {
        (walletOwner,) = makeAddrAndKey("owner");

        (trustedManagerOwner,) = makeAddrAndKey("trustedManagerOwner");
        trustedModuleManager = new TrustedModuleManager(trustedManagerOwner);
        trustedPluginManager = new TrustedPluginManager(trustedManagerOwner);
        securityControlModule = new SecurityControlModule(trustedModuleManager, trustedPluginManager);

        bytes[] memory modules = new bytes[](1);
        modules[0] = abi.encodePacked(securityControlModule, abi.encode(time));
        IPluginManager.Plugin[] memory plugins = new IPluginManager.Plugin[](0);
        bytes32 salt = bytes32(0);
        soulWalletInstence = new SoulWalletInstence(address(0), walletOwner,  modules, plugins,  salt);
        soulWallet = soulWalletInstence.soulWallet();

        (address[] memory _modules, bytes4[][] memory _selectors) = soulWallet.listModule();
        assertEq(_modules.length, 1, "module length error");
        assertEq(_selectors.length, 1, "selector length error");
        assertEq(_modules[0], address(securityControlModule), "module address error");
        assertEq(_selectors[0].length, 4);
        assertEq(_selectors[0][3], bytes4(keccak256("addModule(address,bytes)")), "addModule selector error");
        assertEq(_selectors[0][2], bytes4(keccak256("addPlugin((address,bytes))")), "addPlugin selector error");
        assertEq(_selectors[0][1], bytes4(keccak256("removeModule(address)")), "removeModule selector error");
        assertEq(_selectors[0][0], bytes4(keccak256("removePlugin(address)")), "removePlugin selector error");

        demoModule = new DemoModule();
    }

    //function queue(address _target, bytes calldata _data) external returns (bytes32);
    function addModule_queue() private returns (bytes32) {
        bytes memory initData;
        bytes memory _data =
            abi.encodeWithSelector(bytes4(keccak256("addModule(address,bytes)")), address(demoModule), initData);

        return securityControlModule.queue(address(soulWallet), _data);
    }

    //function cancel(bytes32 _txId) external;
    function addModule_cancel(bytes32 _txId) private {
        securityControlModule.cancel(_txId);
    }

    //function cancelAll() external;
    function addModule_cancelAll() private {
        securityControlModule.cancelAll(address(soulWallet));
    }

    //function execute(address _target, bytes calldata _data) external  ;
    function addModule_execute() private {
        bytes memory initData;
        securityControlModule.execute(
            address(soulWallet),
            abi.encodeWithSelector(bytes4(keccak256("addModule(address,bytes)")), address(demoModule), initData)
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
                            bytes4(keccak256("addModule(address,bytes)")), address(demoModule), initData
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

            assertEq(_modules[0], address(demoModule), "module address error");

            assertEq(soulWallet.isOwner(address(0x1111)), false);
            demoModule.addOwner(address(soulWallet), address(0x1111));
            assertEq(soulWallet.isOwner(address(0x1111)), true, "addOwner error");
        }
    }

    event initEvent(address wallet);
    event deInitEvent(address wallet);

    function test_addModule() public {
        vm.startPrank(trustedManagerOwner);
        address[] memory _modules = new address[](1);
        _modules[0] = address(demoModule);
        trustedModuleManager.add(_modules);
        vm.stopPrank();

        vm.startPrank(walletOwner);
        addModule_queue();
        vm.expectEmit(true, true, true, true); //   (bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData).
        emit initEvent(address(soulWallet));
        addModule_execute();
        vm.stopPrank();

        assertEq(soulWallet.isOwner(address(0x1111)), false);
        demoModule.addOwner(address(soulWallet), address(0x1111));
        assertEq(soulWallet.isOwner(address(0x1111)), true, "addOwner error");
    }

    //function queue(address _target, bytes calldata _data) external returns (bytes32);
    function removeModule_queue() private returns (bytes32) {
        bytes memory _data = abi.encodeWithSelector(bytes4(keccak256("removeModule(address)")), address(demoModule));

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
            address(soulWallet), abi.encodeWithSelector(bytes4(keccak256("removeModule(address)")), address(demoModule))
        );
    }

    function test_removeModule() public {
        test_addModule();

        assertEq(soulWallet.isOwner(address(0x1111)), true, "addOwner error");

        vm.startPrank(walletOwner);
        removeModule_queue();
        vm.expectRevert();
        removeModule_execute();

        vm.warp(block.timestamp + time);
        vm.expectEmit(true, true, true, true); //   (bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData).
        emit deInitEvent(address(soulWallet));
        removeModule_execute();

        vm.expectRevert();
        demoModule.addOwner(address(soulWallet), address(0x2222));
        assertEq(soulWallet.isOwner(address(0x2222)), false, "addOwner error");

        vm.stopPrank();

        (address[] memory _modules,) = soulWallet.listModule();
        assertEq(_modules.length, 1, "module length error");
    }
}
