// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

struct Data {
    address hookAddress;
    bytes hookSignature;
}

contract HookSignatureDecode {
    /**
     * @dev Get the next hook signature
     * @param hookSignatures The hook signatures
     * @param cursor The cursor of the hook signatures
     */
    function _nextHookSignature(bytes calldata hookSignatures, uint256 cursor)
        private
        pure
        returns (address _hookAddr, uint256 _cursorFrom, uint256 _cursorEnd)
    {
        /* 
            +--------------------------------------------------------------------------------+  
            |                            multi-hookSignature                                 |  
            +--------------------------------------------------------------------------------+  
            |     hookSignature     |    hookSignature      |   ...  |    hookSignature      |
            +-----------------------+--------------------------------------------------------+  
            |     dynamic data      |     dynamic data      |   ...  |     dynamic data      |
            +--------------------------------------------------------------------------------+

            +----------------------------------------------------------------------+  
            |                                 hookSignature                        |  
            +----------------------------------------------------------------------+  
            |      Hook address    | hookSignature length  |     hookSignature     |
            +----------------------+-----------------------------------------------+  
            |        20bytes       |     4bytes(uint32)    |         bytes         |
            +----------------------------------------------------------------------+
         */
        uint256 dataLen = hookSignatures.length;

        if (dataLen > cursor) {
            assembly ("memory-safe") {
                let ptr := add(hookSignatures.offset, cursor)
                _hookAddr := shr(0x60, calldataload(ptr))
                if iszero(_hookAddr) { revert(0, 0) }
                _cursorFrom := add(cursor, 24) //20+4
                let guardSigLen := shr(0xe0, calldataload(add(ptr, 20)))
                if iszero(guardSigLen) { revert(0, 0) }
                _cursorEnd := add(_cursorFrom, guardSigLen)
            }
        }
    }

    function decodeSignatureHook(address[] calldata hooks, bytes calldata hookSignatures)
        public
        pure
        returns (Data[] memory)
    {
        address _hookAddr;
        uint256 _cursorFrom;
        uint256 _cursorEnd;
        (_hookAddr, _cursorFrom, _cursorEnd) = _nextHookSignature(hookSignatures, _cursorEnd);

        Data[] memory datas = new Data[](100);
        uint256 _datasIndex = 0;

        for (uint256 i = 0; i < hooks.length; i++) {
            address hookAddress = hooks[i];
            require(uint160(hookAddress) > 1, "invalid hook address");
            {
                bytes calldata currentHookSignature;
                if (hookAddress == _hookAddr) {
                    currentHookSignature = hookSignatures[_cursorFrom:_cursorEnd];
                    // next
                    _hookAddr = address(0);
                    if (_cursorEnd > 0) {
                        (_hookAddr, _cursorFrom, _cursorEnd) = _nextHookSignature(hookSignatures, _cursorEnd);
                    }
                } else {
                    currentHookSignature = hookSignatures[0:0];
                }

                datas[_datasIndex] = Data(hookAddress, currentHookSignature);
                _datasIndex++;
            }
        }
        require(_hookAddr == address(0), "invalid hook signature");

        Data[] memory _datas = new Data[](_datasIndex);
        for (uint256 i = 0; i < _datasIndex; i++) {
            _datas[i] = datas[i];
        }
        return _datas;
    }
}

contract HookSignatureDecodeTest is Test {
    HookSignatureDecode hookSignatureDecode;

    function setUp() public {
        hookSignatureDecode = new HookSignatureDecode();
    }

    function test_decode() public {
        {
            // zero hook
            address[] memory hooks = new address[](0);
            {
                // no hookSignature
                bytes memory hookSignatures = new bytes(0);
                Data[] memory datas = hookSignatureDecode.decodeSignatureHook(hooks, hookSignatures);
                require(datas.length == 0, "invalid datas length");
            }
            {
                // has hookSignature
                address hook1 = address(0x2);
                address hook2 = address(0x3);
                bytes memory hook1Signature = hex"aa";
                bytes memory hook2Signature = hex"bb";
                bytes4 hook1SignatureLength = bytes4(uint32(hook1Signature.length));
                bytes4 hook2SignatureLength = bytes4(uint32(hook2Signature.length));

                bytes memory hookSignatures = abi.encodePacked(
                    hook1, hook1SignatureLength, hook1Signature, hook2, hook2SignatureLength, hook2Signature
                );
                vm.expectRevert("invalid hook signature");
                hookSignatureDecode.decodeSignatureHook(hooks, hookSignatures);
            }
        }
        {
            // one hook
            address[] memory hooks = new address[](1);
            address hook1 = address(0x2);
            hooks[0] = hook1;

            {
                // no hookSignature (correct)
                bytes memory hookSignatures = new bytes(0);
                Data[] memory datas = hookSignatureDecode.decodeSignatureHook(hooks, hookSignatures);
                require(datas.length == 1, "invalid datas length");
                require(datas[0].hookAddress == hook1, "invalid hook address");
                require(datas[0].hookSignature.length == 0, "invalid hook signature length");
            }
            {
                // has hookSignature (correct)
                bytes memory hook1Signature = abi.encode("hook1 signature");
                bytes4 hook1SignatureLength = bytes4(uint32(hook1Signature.length));

                bytes memory hookSignatures = abi.encodePacked(hook1, hook1SignatureLength, hook1Signature);
                Data[] memory datas = hookSignatureDecode.decodeSignatureHook(hooks, hookSignatures);
                require(datas.length == 1, "invalid datas length");
                require(datas[0].hookAddress == hook1, "invalid hook address");
                assertEq(datas[0].hookSignature, hook1Signature, "invalid hook signature");
            }
            {
                // has hookSignature (incorrect)
                bytes memory hook1Signature = abi.encode("hook1 signature");
                bytes4 hook1SignatureLength = bytes4(uint32(hook1Signature.length));

                bytes memory hookSignatures = abi.encodePacked(address(3), hook1SignatureLength, hook1Signature);
                vm.expectRevert("invalid hook signature");
                hookSignatureDecode.decodeSignatureHook(hooks, hookSignatures);
            }
            {
                // has hookSignature (incorrect)
                bytes memory hook1Signature = abi.encode("hook1 signature");
                bytes4 hook1SignatureLength = bytes4(uint32(hook1Signature.length));

                bytes memory hookSignatures = abi.encodePacked(hook1, hook1SignatureLength, hook1Signature, hook1);
                vm.expectRevert();
                hookSignatureDecode.decodeSignatureHook(hooks, hookSignatures);
            }
            {
                // has hookSignature (incorrect)
                bytes memory hook1Signature = abi.encode("hook1 signature");
                bytes4 hook1SignatureLength = bytes4(uint32(hook1Signature.length));

                bytes memory hookSignatures = abi.encodePacked(
                    hook1, hook1SignatureLength, hook1Signature, hook1, hook1SignatureLength, hook1Signature
                );
                vm.expectRevert();
                hookSignatureDecode.decodeSignatureHook(hooks, hookSignatures);
            }
        }
        {
            // two hooks
            address[] memory hooks = new address[](2);
            address hook1 = address(0x2);
            address hook2 = address(0x3);
            hooks[0] = hook1;
            hooks[1] = hook2;

            {
                // no hookSignature (correct)
                bytes memory hookSignatures = new bytes(0);
                Data[] memory datas = hookSignatureDecode.decodeSignatureHook(hooks, hookSignatures);
                require(datas.length == 2, "invalid datas length");
                require(datas[0].hookAddress == hook1, "invalid hook address");
                require(datas[0].hookSignature.length == 0, "invalid hook signature length");
                require(datas[1].hookAddress == hook2, "invalid hook address");
                require(datas[1].hookSignature.length == 0, "invalid hook signature length");
            }
            {
                // has hookSignature (correct)
                bytes memory hook1Signature = abi.encode("hook1 signature");
                bytes4 hook1SignatureLength = bytes4(uint32(hook1Signature.length));

                bytes memory hookSignatures = abi.encodePacked(hook1, hook1SignatureLength, hook1Signature);
                Data[] memory datas = hookSignatureDecode.decodeSignatureHook(hooks, hookSignatures);
                require(datas.length == 2, "invalid datas length");
                require(datas[0].hookAddress == hook1, "invalid hook address");
                assertEq(datas[0].hookSignature, hook1Signature, "invalid hook signature");
                require(datas[1].hookAddress == hook2, "invalid hook address");
                require(datas[1].hookSignature.length == 0, "invalid hook signature length");
            }
            {
                // has hookSignature (correct)
                bytes memory hook2Signature = abi.encode("hook2 signature");
                bytes4 hook2SignatureLength = bytes4(uint32(hook2Signature.length));

                bytes memory hookSignatures = abi.encodePacked(hook2, hook2SignatureLength, hook2Signature);
                Data[] memory datas = hookSignatureDecode.decodeSignatureHook(hooks, hookSignatures);
                require(datas.length == 2, "invalid datas length");
                require(datas[0].hookAddress == hook1, "invalid hook address");
                assertEq(datas[0].hookSignature, hex"", "invalid hook signature");
                require(datas[1].hookAddress == hook2, "invalid hook address");
                assertEq(datas[1].hookSignature, hook2Signature, "invalid hook signature");
            }
            {
                // has hookSignature (incorrect)
                bytes memory hook1Signature = abi.encode("hook1 signature");
                bytes4 hook1SignatureLength = bytes4(uint32(hook1Signature.length));

                bytes memory hookSignatures = abi.encodePacked(address(5), hook1SignatureLength, hook1Signature);
                vm.expectRevert("invalid hook signature");
                hookSignatureDecode.decodeSignatureHook(hooks, hookSignatures);
            }
        }
    }
}
