// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2, Test} from "forge-std/Test.sol";

import {UserOperation} from "../contracts/interface/IAccount.sol";
import {IValidator} from "../contracts/interface/IValidator.sol";
import {CallDataPack} from "../contracts/utils/CallDataPack.sol";

contract CalldataPackLib {
    function decodeBytes(bytes calldata data) public pure {
        console2.log("========================== decodeBytes ==========================");

        /*
            address sender;
            uint256 nonce;
            bytes initCode;
            bytes callData;
            uint256 callGasLimit;
            uint256 verificationGasLimit;
            uint256 preVerificationGas;
            uint256 maxFeePerGas;
            uint256 maxPriorityFeePerGas;
            bytes paymasterAndData;
            bytes signature;
        */
        uint256 len = data.length / 32;
        for (uint256 i = 0; i < len; i++) {
            console2.logBytes32(bytes32(data[i * 32:(i + 1) * 32]));
        }
    }

    function test_pack1(UserOperation calldata userOp, bytes32 userOpHash, bytes calldata validatorSignature)
        public
        pure
        returns (bytes memory callData1, bytes memory callData2)
    {
        UserOperation memory _userOp = userOp;
        _userOp.signature = "";
        callData1 = abi.encodeWithSelector(IValidator.validateUserOp.selector, _userOp, userOpHash, validatorSignature);
        callData2 = CallDataPack.encodeWithoutUserOpSignature_validateUserOp_UserOperation_bytes32_bytes(
            userOp, userOpHash, validatorSignature
        );
    }

    function test_pack_1(UserOperation calldata userOp, bytes32 userOpHash, bytes calldata validatorSignature)
        public
        pure
    {
        abi.encodeWithSelector(IValidator.validateUserOp.selector, userOp, userOpHash, validatorSignature);
    }

    function test_pack_2(UserOperation calldata userOp, bytes32 userOpHash, bytes calldata validatorSignature)
        public
        pure
    {
        CallDataPack.encodeWithoutUserOpSignature_validateUserOp_UserOperation_bytes32_bytes(
            userOp, userOpHash, validatorSignature
        );
    }
}

contract CalldataPackTest is Test {
    CalldataPackLib _CalldataPackLib;

    function setUp() public {
        _CalldataPackLib = new CalldataPackLib();
    }

    function getUserOp() private pure returns (UserOperation memory) {
        address sender = address(0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa);
        uint256 nonce = 0x0b0b0b0b0b0b0b;
        bytes memory initCode = hex"0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c";
        bytes memory callData = hex"0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d";
        uint256 callGasLimit = 0x0e0e0e0e0e0e0e;
        uint256 verificationGasLimit = 0x0f0f0f0f0f0f0f;
        uint256 preVerificationGas = 0x10101010101010;
        uint256 maxFeePerGas = 0x11111111111111;
        uint256 maxPriorityFeePerGas = 0x12121212121212;
        bytes memory paymasterAndData = hex"13131313131313131313131313";
        bytes memory signature = hex"14141414141414141414141414";
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

        return userOperation;
    }

    function test_pack1() public {
        UserOperation memory userOp = getUserOp();
        bytes32 userOpHash = hex"0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a";
        bytes memory validatorSignature = hex"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";

        (bytes memory callData1, bytes memory callData2) =
            _CalldataPackLib.test_pack1(userOp, userOpHash, validatorSignature);

        bytes memory padding = hex"cccccccccccccccccccccccccccccccccccccccccccccccccccccccc";

        console2.log("use abi.encodeWithSelector:");
        _CalldataPackLib.decodeBytes(abi.encodePacked(padding, callData1));
        console2.log("use CallDataPack:");
        _CalldataPackLib.decodeBytes(abi.encodePacked(padding, callData2));

        assertEq(callData1, callData2);
    }

    function test_gasCheck() public {
        UserOperation memory userOp = getUserOp();
        bytes32 userOpHash = hex"0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a";
        bytes memory validatorSignature =
            hex"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";

        _CalldataPackLib.test_pack_1(userOp, userOpHash, validatorSignature);
        uint256 snapshotId = vm.snapshot();
        {
            // len: 20+4+65 = 89
            userOp.signature =
                hex"1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f";

            vm.revertTo(snapshotId);
            uint256 gasBefore1 = gasleft();
            _CalldataPackLib.test_pack_1(userOp, userOpHash, validatorSignature);
            uint256 gasAfter1 = gasleft();
            uint256 gasCost1 = gasBefore1 - gasAfter1;

            vm.revertTo(snapshotId);
            uint256 gasBefore2 = gasleft();
            _CalldataPackLib.test_pack_2(userOp, userOpHash, validatorSignature);
            uint256 gasAfter2 = gasleft();
            uint256 gasCost2 = gasBefore2 - gasAfter2;

            uint256 gasDiff_EOASignature = gasCost1 - gasCost2;

            console2.log("gasDiff_EOASignature:", gasDiff_EOASignature);
        }

        {
            // len: refer: https://testnet.arbiscan.io/tx/0xf75787a5da075071d256f18baa6d964c5a3bdff15bd190629262c21827dc4b5a
            userOp.signature =
                hex"00030000655b18e90000655b26f9000000000000000000000000000000000000000000b57c1c13f680eb086a7410214d7eee06698c7d12430f7aceba9eb00b2d136b084e725bfaadfcfaced8d03ab83a56e79d1e86c55e187f8a865a294bf9191ec01d1b00250000c1a4a4e2d6a23ce7c726bf5f4b5d96354a80e8f7b55128e04fe39611387b9bad0500000000222c226f726967696e223a2268747470733a2f2f616c7068612e736f756c77616c6c65742e696f222c2263726f73734f726967696e223a66616c73657d";

            vm.revertTo(snapshotId);
            uint256 gasBefore1 = gasleft();
            _CalldataPackLib.test_pack_1(userOp, userOpHash, validatorSignature);
            uint256 gasAfter1 = gasleft();
            uint256 gasCost1 = gasBefore1 - gasAfter1;

            vm.revertTo(snapshotId);
            uint256 gasBefore2 = gasleft();
            _CalldataPackLib.test_pack_2(userOp, userOpHash, validatorSignature);
            uint256 gasAfter2 = gasleft();
            uint256 gasCost2 = gasBefore2 - gasAfter2;

            uint256 gasDiff_es256 = gasCost1 - gasCost2;
            console2.log("gasDiff_es256:", gasDiff_es256);
        }

        {
            // len: refer: https://testnet.arbiscan.io/tx/0xf75787a5da075071d256f18baa6d964c5a3bdff15bd190629262c21827dc4b5a
            userOp.signature =
                hex"00030000655b18e90000655b26f9000000000000000000000000000000000000000000b57c1c13f680eb086a7410214d7eee06698c7d12430f7aceba9eb00b2d136b084e725bfaadfcfaced8d03ab83a56e79d1e86c55e187f8a865a294bf9191ec01d1b00250000c1a4a4e2d6a23ce7c726bf5f4b5d96354a80e8f7b55128e04fe39611387b9bad0500000000222c226f726967696e223a2268747470733a2f2f616c7068612e736f756c77616c6c65742e696f222c2263726f73734f726967696e223a66616c73657d1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e";

            vm.revertTo(snapshotId);
            uint256 gasBefore1 = gasleft();
            _CalldataPackLib.test_pack_1(userOp, userOpHash, validatorSignature);
            uint256 gasAfter1 = gasleft();
            uint256 gasCost1 = gasBefore1 - gasAfter1;

            vm.revertTo(snapshotId);
            uint256 gasBefore2 = gasleft();
            _CalldataPackLib.test_pack_2(userOp, userOpHash, validatorSignature);
            uint256 gasAfter2 = gasleft();
            uint256 gasCost2 = gasBefore2 - gasAfter2;

            uint256 gasDiff_es256 = gasCost1 - gasCost2;
            console2.log("gasDiff_es256 with 1k hookdata", gasDiff_es256);
        }

        {
            // len: refer: https://testnet.arbiscan.io/tx/0xf75787a5da075071d256f18baa6d964c5a3bdff15bd190629262c21827dc4b5a
            userOp.signature =
                hex"00030000655b18e90000655b26f9000000000000000000000000000000000000000000b57c1c13f680eb086a7410214d7eee06698c7d12430f7aceba9eb00b2d136b084e725bfaadfcfaced8d03ab83a56e79d1e86c55e187f8a865a294bf9191ec01d1b00250000c1a4a4e2d6a23ce7c726bf5f4b5d96354a80e8f7b55128e04fe39611387b9bad0500000000222c226f726967696e223a2268747470733a2f2f616c7068612e736f756c77616c6c65742e696f222c2263726f73734f726967696e223a66616c73657d1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e";

            vm.revertTo(snapshotId);
            uint256 gasBefore1 = gasleft();
            _CalldataPackLib.test_pack_1(userOp, userOpHash, validatorSignature);
            uint256 gasAfter1 = gasleft();
            uint256 gasCost1 = gasBefore1 - gasAfter1;

            vm.revertTo(snapshotId);
            uint256 gasBefore2 = gasleft();
            _CalldataPackLib.test_pack_2(userOp, userOpHash, validatorSignature);
            uint256 gasAfter2 = gasleft();
            uint256 gasCost2 = gasBefore2 - gasAfter2;

            uint256 gasDiff_es256 = gasCost1 - gasCost2;
            console2.log("gasDiff_es256 with 2k hookdata", gasDiff_es256);
        }
    }
}
