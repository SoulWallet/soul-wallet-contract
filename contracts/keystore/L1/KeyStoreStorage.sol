// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./interfaces/IKeyStore.sol";
import "../../libraries/Errors.sol";

abstract contract KeyStoreStorage is IKeyStore {
    uint64 internal constant _GUARDIAN_PERIOD_MIN = 2 days;
    uint64 internal constant _GUARDIAN_PERIOD_MAX = 30 days;

    constructor() {}

    function _getNonce(bytes32 slot) internal view returns (uint256 _nonce) {
        assembly {
            _nonce := sload(add(slot, 1))
        }
    }

    function _increaseNonce(bytes32 slot) internal {
        assembly {
            slot := add(slot, 1)
            sstore(slot, add(sload(slot), 1))
        }
    }

    function _keyGuard(bytes32 key) internal view virtual {
        if (key == bytes32(0)) {
            revert Errors.INVALID_KEY();
        }
    }

    function _saveKey(bytes32 slot, bytes32 key) internal {
        _keyGuard(key);
        assembly {
            sstore(slot, key)
        }
        emit KeyChanged(slot, key);
    }

    function _getKey(bytes32 slot) internal view returns (bytes32 key) {
        assembly {
            key := sload(slot)
        }
    }

    function _getKey(bytes32 slot, bytes32 initialKey) internal view returns (bytes32 key) {
        assembly {
            key := sload(slot)
            if eq(key, 0) { key := initialKey }
        }
    }

    function _getGuardianInfo(bytes32 slot) internal pure returns (guardianInfo storage _guardianInfo) {
        assembly ("memory-safe") {
            slot := add(slot, 2)
            _guardianInfo.slot := slot
        }
    }

    function _storeRawOwnerBytes(bytes32 slot, bytes memory data) internal {
        assembly {
            // raw owners offset
            slot := add(slot, 5)
            // calcuate the length of raw owners
            sstore(slot, mload(data))
            /* rounding up when divide by 32
            For a bytes length of 1: (1 + 31) / 32 equals 32 / 32, which is 1.
            For a bytes length of 32: (32 + 31) / 32 also equals 63 / 32, which rounds down to 1.
            For a bytes length of 33: (33 + 31) / 32 equals 64 / 32, which is 2.
            */
            let dataLength := div(add(mload(data), 31), 32)
            // skip the length offset
            let dataPtr := add(data, 0x20)

            for { let i := 0 } lt(i, dataLength) { i := add(i, 1) } {
                sstore(add(slot, add(i, 1)), mload(dataPtr))
                dataPtr := add(dataPtr, 0x20)
            }
        }
    }

    function _getRawOwners(bytes32 slot) internal view returns (bytes memory rawOwners) {
        uint256 length;
        // get length of array
        assembly {
            length := sload(add(slot, 5))
        }
        rawOwners = new bytes(length);
        for (uint256 i = 0; i < length; i += 32) {
            bytes32 chunk;
            assembly {
                chunk := sload(add(slot, add(6, div(i, 32))))
            }
            for (uint256 j = 0; j < 32 && i + j < length; j++) {
                rawOwners[i + j] = bytes1(uint8(chunk[j]));
            }
        }
        return rawOwners;
    }

    function _getkeyStoreInfo(bytes32 slot) internal pure returns (keyStoreInfo storage _keyStoreInfo) {
        assembly ("memory-safe") {
            _keyStoreInfo.slot := slot
        }
    }
}
