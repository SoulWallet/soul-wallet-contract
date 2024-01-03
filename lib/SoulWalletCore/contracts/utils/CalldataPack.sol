// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UserOperation} from "../interface/IAccount.sol";
import {IValidator} from "../interface/IValidator.sol";

library CallDataPack {
    /**
     * @dev Executing abi.encodeWithSelector with a custom function can save at least 1322 gas (when the signature length is 89), and the savings are even greater in cases where userOp contains a longer signature or hookData.
     *
     * Benchmark: `forge test -vv --match-contract "CalldataPackTest" | grep 'gasDiff'`
     * Result:
     * gasDiff_EOASignature: 1322
     * gasDiff_es256: 1390
     * gasDiff_es256 with 1k hookdata 1744
     * gasDiff_es256 with 2k hookdata 2087
     *
     * Whether to remove userOp.signature from calldata depends on the position of userOp.signature
     * If userOp.signature is not the last field, it will be included in the encoded result
     * If userOp.signature is the last field, it will not be included in the encoded result
     */
    function encodeWithoutUserOpSignature_validateUserOp_UserOperation_bytes32_bytes(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        bytes calldata validatorSignature
    ) internal pure returns (bytes memory callData) {
        /*
            Equivalent code:
            UserOperation memory _userOp = userOp;
            _userOp.signature = "";
            bytes memory callData = abi.encodeWithSelector(IValidator.validateUserOp.selector, _userOp, userOpHash, validatorSignature);
         */

        /* 
            struct UserOperation {
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
            }

            In calldata, the data structure of the UserOperation is always: 
                refer to:https://docs.soliditylang.org/en/develop/abi-spec.html
         offset: 0x00   000000000000000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa # sender
         offset: 0x20   000000000000000000000000000000000000000000000000000b0b0b0b0b0b0b # nonce
         offset: 0x40   0000000000000000000000000000000000000000000000000000000000000160 # initCode offset
         offset: 0x60   00000000000000000000000000000000000000000000000000000000000001a0 # callData offset
         offset: 0x80   000000000000000000000000000000000000000000000000000e0e0e0e0e0e0e # callGasLimit
         offset: 0xa0   000000000000000000000000000000000000000000000000000f0f0f0f0f0f0f # verificationGasLimit
         offset: 0xc0   0000000000000000000000000000000000000000000000000010101010101010 # preVerificationGas
         offset: 0xe0   0000000000000000000000000000000000000000000000000011111111111111 # maxFeePerGas
         offset:0x100   0000000000000000000000000000000000000000000000000012121212121212 # maxPriorityFeePerGas
         offset:0x120   00000000000000000000000000000000000000000000000000000000000001e0 # paymasterAndData offset
         offset:0x140   0000000000000000000000000000000000000000000000000000000000000220 # signature offset
                        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx ──┐
                        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx   │ dynamic data
                        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx   │
                        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx ──┘

            
            In the known SDK implementation, the last field `signature` of the struct is packed at the end.
            However, manual encoding allows the position of signature to be moved earlier (still valid data).
            In our process, we detect the position of signature. If it's not the last field, we fallback to encoding with `abi.encodeWithSelector()`.
            If signature is detected as the last field, we can construct calldata with low cost using calldatacopy.
        */

        // Check if userOp.signature is the last field, if not, fallback to `abi.encodeWithSelector()`
        {
            uint256 lastfield = 0; // 0: last field is signature, 1: last field is not signature
            assembly ("memory-safe") {
                let userOpOffset := userOp
                let _initCodeOffset := calldataload(add(userOpOffset, 0x40))
                let _signatureOffset := calldataload(add(userOpOffset, 0x140))
                // if(_initCodeOffset >= _signatureOffset) { lastfield = 1 }
                if iszero(lt(_initCodeOffset, _signatureOffset)) { lastfield := 1 }

                let _callDataOffset := calldataload(add(userOpOffset, 0x60))
                // if(_callDataOffset >= _signatureOffset) { lastfield = 1 }
                if iszero(lt(_callDataOffset, _signatureOffset)) { lastfield := 1 }

                let _paymasterAndDataOffset := calldataload(add(userOpOffset, 0x120))
                // if(_paymasterAndDataOffset >= _signatureOffset) { lastfield = 1 }
                if iszero(lt(_paymasterAndDataOffset, _signatureOffset)) { lastfield := 1 }
            }
            if (lastfield == 1) {
                return
                    abi.encodeWithSelector(IValidator.validateUserOp.selector, userOp, userOpHash, validatorSignature);
            }
        }

        /**
         * The validatorSignature comes from the slice of the Signature,
         * so don't try to get the length of the validatorSignature via calldataload(sub(validatorSignature.offset,32))
         */
        uint256 validatorSignatureLength = validatorSignature.length;
        bytes4 selector = IValidator.validateUserOp.selector;
        assembly ("memory-safe") {
            /*
                The structure of calldata is:
                    refer to:https://docs.soliditylang.org/en/develop/abi-spec.html

                                                                        5d719936 # selector
                0000000000000000000000000000000000000000000000000000000000000060 # offset of userOp
                0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a # userOpHash
                00000000000000000000000000000000000000000000000000000000000002a0 # offset of validatorSignature
                000000000000000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ──┐
                000000000000000000000000000000000000000000000000000b0b0b0b0b0b0b   │
                0000000000000000000000000000000000000000000000000000000000000160   │
                00000000000000000000000000000000000000000000000000000000000001a0   │
                000000000000000000000000000000000000000000000000000e0e0e0e0e0e0e   │
                000000000000000000000000000000000000000000000000000f0f0f0f0f0f0f   │
                0000000000000000000000000000000000000000000000000010101010101010   │
                0000000000000000000000000000000000000000000000000011111111111111   ├── userOp (signature length is 0)
                0000000000000000000000000000000000000000000000000012121212121212   │
                00000000000000000000000000000000000000000000000000000000000001e0   │
                0000000000000000000000000000000000000000000000000000000000000220   │
                0000000000000000000000000000000000000000000000000000000000000010   │
                0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c00000000000000000000000000000000   │
                0000000000000000000000000000000000000000000000000000000000000010   │
                0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d00000000000000000000000000000000   │
                000000000000000000000000000000000000000000000000000000000000000d   │
                1313131313131313131313131300000000000000000000000000000000000000   │
                0000000000000000000000000000000000000000000000000000000000000000 ──┴── (validatorSignature length is 0)
                0000000000000000000000000000000000000000000000000000000000000020 # validatorSignature length
                xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx # validatorSignature

             */
            // Offset of userOp in calldata
            let userOpOffset := userOp
            let _signatureOffset := calldataload(add(userOpOffset, 0x140))

            /*
                Length of userOp, excluding signature, but includes an additional 32bytes for recording the length of signature = 0
                The length should be a multiple of 32, so no need for alignment like ValidatorSignatureLength
             */
            let paddedUserOpLength := add(_signatureOffset, 32)

            // Round up to the nearest multiple of 32, bytes<M>: enc(X) is the sequence of bytes in X padded with trailing zero-bytes to a length of 32 bytes.
            let paddedValidatorSignatureLength := mul(div(add(validatorSignatureLength, 31), 32), 32)

            // Total length of call data: 4(selecter) + 32(offset of userOp) + 32(userOpHash) + 32(offset of validatorSignature) + paddedUserOpLength + 32(validatorSignature length)+ paddedValidatorSignatureLength
            let callDataLength := add(add(132, paddedUserOpLength), paddedValidatorSignatureLength)

            // Allocate memory: callDataLength - 4 bytes header + 32 (padding 4 bytes header to 32 bytes) + 32 (record data length)
            let ptr := mload(0x40)
            mstore(0x40, add(add(32, ptr), add(32, add(callDataLength, 28))))

            // 4 bytes header and callData length, shift callData length 4bytes to align with selector in the same storage slot
            mstore(add(0x20, ptr), or(shl(32, callDataLength), shr(224, selector))) // Shift 4-byte header right by 8*(32-4)
            //  offset of userOp
            mstore(add(0x40, ptr), 0x60)
            // userOp Hash
            mstore(add(0x60, ptr), userOpHash)
            // offset of validatorSignature, paddedUserOpLength+ 3*0x20
            mstore(add(0x80, ptr), add(paddedUserOpLength, 0x60))
            // userOp
            calldatacopy(add(0xa0, ptr), userOpOffset, paddedUserOpLength)
            let validatorSignatureOffset := add(add(0xa0, ptr), paddedUserOpLength)
            /*
                Set the signature length to 0, as an extra 32bytes data (original length of signature) was copied in the previous step of calldatacopy
             */
            mstore(sub(validatorSignatureOffset, 32), 0)
            // validatorSignature length
            mstore(validatorSignatureOffset, validatorSignatureLength)
            // validatorSignature
            calldatacopy(add(0x20, validatorSignatureOffset), validatorSignature.offset, paddedValidatorSignatureLength)
            // Non-32 alignment, 0x20-0x04, to follow bytes4-selecter immediately after callData length
            callData := add(ptr, 28)
        }
    }
}
