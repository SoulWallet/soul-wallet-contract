// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

library DecodeCalldata {
    function decodeMethodId(bytes memory data) internal pure returns (bytes4 methodId) {
        assembly ("memory-safe") {
            let dataLength := mload(data)
            if lt(dataLength, 0x04) { revert(0, 0) }
            methodId := mload(add(data, 0x20))
        }
    }

    function decodeMethodCalldata(bytes memory data) internal pure returns (bytes memory MethodCalldata) {
        assembly ("memory-safe") {
            let dataLength := mload(data)
            if lt(dataLength, 0x04) { revert(0, 0) }
            let methodDataLength := sub(dataLength, 0x04)
            MethodCalldata := mload(0x40)
            mstore(0x40, add(MethodCalldata, and(add(methodDataLength, 0x3f), not(0x1f))))
            mstore(MethodCalldata, methodDataLength)
            let MethodCalldataStart := add(MethodCalldata, 0x20)
            let dataStart := add(data, 0x24)
            for { let i := 0x00 } lt(i, methodDataLength) { i := add(i, 0x20) } {
                mstore(add(MethodCalldataStart, i), mload(add(dataStart, i)))
            }
        }
    }
}
