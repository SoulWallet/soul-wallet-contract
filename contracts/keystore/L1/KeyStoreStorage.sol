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

    function _getkeyStoreInfo(bytes32 slot) internal pure returns (keyStoreInfo storage _keyStoreInfo) {
        assembly ("memory-safe") {
            _keyStoreInfo.slot := slot
        }
    }
}
