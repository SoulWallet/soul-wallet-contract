// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../base/SoulWalletInstence.sol";
import "@source/modules/SecurityControlModule/SecurityControlModule.sol";
import "@source/trustedContractManager/trustedModuleManager/TrustedModuleManager.sol";
import "@source/trustedContractManager/trustedPluginManager/TrustedPluginManager.sol";
import "@source/dev/DemoModule.sol";
import "@source/dev/DemoPlugin.sol";
import "../Bundler.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@source/dev/Tokens/TokenERC20.sol";

contract SecurityControlModuleTest is Test {
    using ECDSA for bytes32;

    SoulWalletInstence public soulWalletInstence;
    ISoulWallet public soulWallet;
    SecurityControlModule public securityControlModule;
    TrustedModuleManager public trustedModuleManager;
    TrustedPluginManager public trustedPluginManager;
    DemoModule public demoModule;
    uint64 public time = 2 days;
    address public walletOwner;
    address trustedManagerOwner;
    DemoPlugin public demoPlugin_init;
    DemoPlugin public demoPlugin;
    uint256 public walletOwnerPrivateKey;
    Bundler public bundler;
    TokenERC20 public token;

    function setUp() public {
        (walletOwner, walletOwnerPrivateKey) = makeAddrAndKey("owner");

        (trustedManagerOwner,) = makeAddrAndKey("trustedManagerOwner");
        trustedModuleManager = new TrustedModuleManager(trustedManagerOwner);
        trustedPluginManager = new TrustedPluginManager(trustedManagerOwner);
        securityControlModule = new SecurityControlModule(trustedModuleManager, trustedPluginManager);
        demoPlugin_init = new DemoPlugin();

        bytes[] memory modules = new bytes[](1);
        modules[0] = abi.encodePacked(securityControlModule, abi.encode(time));
        bytes[] memory plugins = new bytes[](1);
        bytes memory demoPlugin_init_initData;
        plugins[0] = abi.encodePacked(address(demoPlugin_init), demoPlugin_init_initData);
        bytes32 salt = bytes32(0);
        soulWalletInstence = new SoulWalletInstence(address(0), walletOwner,  modules, plugins,  salt);
        soulWallet = soulWalletInstence.soulWallet();

        (address[] memory _modules, bytes4[][] memory _selectors) = soulWallet.listModule();
        assertEq(_modules.length, 1, "module length error");
        assertEq(_selectors.length, 1, "selector length error");
        assertEq(_modules[0], address(securityControlModule), "module address error");
        assertEq(_selectors[0].length, 4);
        assertEq(_selectors[0][3], bytes4(keccak256("addModule(bytes)")), "addModule selector error");
        assertEq(_selectors[0][2], bytes4(keccak256("addPlugin(bytes)")), "addPlugin selector error");
        assertEq(_selectors[0][1], bytes4(keccak256("removeModule(address)")), "removeModule selector error");
        assertEq(_selectors[0][0], bytes4(keccak256("removePlugin(address)")), "removePlugin selector error");

        demoModule = new DemoModule();
        demoPlugin = new DemoPlugin();
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
                bytes4(keccak256("addModule(bytes)")), abi.encodePacked(address(demoModule), initData)
            )
        );
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
            abi.encodeWithSelector(
                bytes4(keccak256("addModule(bytes)")), abi.encodePacked(address(demoModule), initData)
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
                            bytes4(keccak256("addModule(bytes)")), abi.encodePacked(address(demoModule), initData)
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

    // #endregion

    // #region Plugin

    //function queue(address _target, bytes calldata _data) external returns (bytes32);
    function addPlugin_queue() private returns (bytes32) {
        bytes memory initData;
        return securityControlModule.queue(
            address(soulWallet),
            abi.encodeWithSelector(
                bytes4(keccak256("addPlugin(bytes)")), abi.encodePacked(address(demoPlugin), initData)
            )
        );
    }

    //function execute(address _target, bytes calldata _data) external  ;
    function addPlugin_execute() private {
        bytes memory initData;
        securityControlModule.execute(
            address(soulWallet),
            abi.encodeWithSelector(
                bytes4(keccak256("addPlugin(bytes)")), abi.encodePacked(address(demoPlugin), initData)
            )
        );
    }

    event PluginInit(address indexed addr);
    event PluginDeInit(address indexed addr);

    function test_addPlugin() public {
        vm.startPrank(trustedManagerOwner);
        address[] memory _plugins = new address[](1);
        _plugins[0] = address(demoPlugin);
        trustedPluginManager.add(_plugins);
        vm.stopPrank();

        vm.startPrank(walletOwner);
        vm.expectEmit(true, true, true, true); //   (bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData).
        emit PluginInit(address(soulWallet));
        addPlugin_execute();
        vm.stopPrank();
    }

    function test_addPlugin_withoutWhiteList() public {
        vm.startPrank(walletOwner);

        vm.expectRevert();
        addPlugin_execute();

        addPlugin_queue();

        vm.expectRevert();
        addPlugin_execute();

        vm.warp(block.timestamp + time);
        addPlugin_execute();

        vm.stopPrank();
    }

    event OnGuardHook();
    event OnPreHook();
    event OnPostHook();

    function test_Plugin() public {
        test_addPlugin();
        address sender = address(soulWallet);

        token.sudoMint(sender, 1000);

        uint256 nonce = 0;
        bytes memory initCode;
        bytes memory callData;
        uint256 callGasLimit;
        uint256 verificationGasLimit;
        uint256 preVerificationGas;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        bytes memory paymasterAndData;
        bytes memory signature;
        {
            verificationGasLimit = 1000000;
            preVerificationGas = 100000;
            maxFeePerGas = 10 gwei;
            maxPriorityFeePerGas = 10 gwei;

            // transfer ERC20
            bytes memory transferData =
                abi.encodeWithSelector(bytes4(keccak256("transfer(address,uint256)")), address(0x1111), 100);
            callData = abi.encodeWithSelector(
                bytes4(keccak256("execute(address,uint256,bytes)")), address(token), 0, transferData
            );
            callGasLimit = 1000000;
        }

        UserOperation memory userOperation = UserOperation(
            sender,
            nonce,
            initCode,
            callData,
            callGasLimit,
            verificationGasLimit,
            preVerificationGas,
            maxFeePerGas,
            maxPriorityFeePerGas,
            paymasterAndData,
            signature
        );

        bytes32 userOpHash = soulWalletInstence.entryPoint().getUserOpHash(userOperation);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(walletOwnerPrivateKey, userOpHash.toEthSignedMessageHash());
        userOperation.signature = abi.encodePacked(r, s, v);

        vm.deal(userOperation.sender, 10 ether);

        vm.expectEmit(true, true, true, true);
        emit OnGuardHook();
        vm.expectEmit(true, true, true, true);
        emit OnPreHook();
        vm.expectEmit(true, true, true, true);
        emit OnPostHook();
        bundler.post(soulWalletInstence.entryPoint(), userOperation);

        assertEq(token.balanceOf(address(0x1111)), 100, "transfer error");
    }

    // #endregion
}
