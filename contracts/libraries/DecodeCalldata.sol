// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

library DecodeCalldata {

    function decodeMethodId(
        bytes memory data
    ) internal pure returns (bytes4 methodId) {
        assembly {
            let dataLength := mload(data)
            if lt(dataLength, 0x04) {
                revert(0, 0)
            }
            methodId := mload(add(data, 0x20))
        }
    }
    
}
