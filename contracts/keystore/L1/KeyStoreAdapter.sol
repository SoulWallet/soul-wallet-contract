// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./interfaces/IKeyStoreStorage.sol";
import "./interfaces/IKeyStore.sol";
import "../../libraries/Errors.sol";

abstract contract KeyStoreAdapter is IKeyStore {
    uint256 internal constant _GUARDIAN_PERIOD_MIN = 2 days;
    uint256 internal constant _GUARDIAN_PERIOD_MAX = 30 days;

    function keyStoreStorage() public view virtual returns (IKeyStoreStorage);

    function _getNonce(bytes32 slot) internal view returns (uint256 _nonce) {
        return keyStoreStorage().getUint256(slot, "nonce");
    }

    function _increaseNonce(bytes32 slot) internal {
        uint256 _newNonce = _getNonce(slot) + 1;
        keyStoreStorage().setUint256(slot, "nonce", _newNonce);
    }

    function _keyGuard(bytes32 key) internal view virtual {
        if (key == bytes32(0)) {
            revert Errors.INVALID_KEY();
        }
    }

    function _saveKey(bytes32 slot, bytes32 key) internal {
        _keyGuard(key);
        keyStoreStorage().setSlotValue(slot, key);
        emit KeyChanged(slot, key);
    }

    function _getKey(bytes32 slot) internal view returns (bytes32 key) {
        return keyStoreStorage().getSlotValue(slot);
    }

    function _getGuardianHash(bytes32 slot) internal view returns (bytes32 key) {
        return keyStoreStorage().getBytes32(slot, "guardianHash");
    }

    function _setGuardianHash(bytes32 slot, bytes32 _guardianHash) internal {
        return keyStoreStorage().setBytes32(slot, "guardianHash", _guardianHash);
    }

    function _getPendingGuardianHash(bytes32 slot) internal view returns (bytes32 key) {
        return keyStoreStorage().getBytes32(slot, "pendingGuardianHash");
    }

    function _setPendingGuardianHash(bytes32 slot, bytes32 _guardianHash) internal {
        return keyStoreStorage().setBytes32(slot, "pendingGuardianHash", _guardianHash);
    }

    function _getGuardianActivateAt(bytes32 slot) internal view returns (uint256) {
        return keyStoreStorage().getUint256(slot, "guardianActivateAt");
    }

    function _setGuardianActivateAt(bytes32 slot, uint256 _guardianActiveAt) internal {
        return keyStoreStorage().setUint256(slot, "guardianActivateAt", _guardianActiveAt);
    }

    function _getGuardianSafePeriod(bytes32 slot) internal view returns (uint256) {
        return keyStoreStorage().getUint256(slot, "guardianSafePeriod");
    }

    function _setGuardianSafePeriod(bytes32 slot, uint256 _guardianSafePeriod) internal {
        keyStoreStorage().setUint256(slot, "guardianSafePeriod", _guardianSafePeriod);
    }

    function _getPendingGuardianSafePeriod(bytes32 slot) internal view returns (uint256) {
        return keyStoreStorage().getUint256(slot, "pendingGuardianSafePeriod");
    }

    function _setPendingGuardianSafePeriod(bytes32 slot, uint256 _pendingGuardianSafePeriod) internal {
        keyStoreStorage().setUint256(slot, "pendingGuardianSafePeriod", _pendingGuardianSafePeriod);
    }

    function _getGuardianSafePeriodActivateAt(bytes32 slot) internal view returns (uint256) {
        return keyStoreStorage().getUint256(slot, "guardianSafePeriodActivateAt");
    }

    function _setGuardianSafePeriodActivateAt(bytes32 slot, uint256 _guardianSafePeriodActivateAt) internal {
        keyStoreStorage().setUint256(slot, "guardianSafePeriodActivateAt", _guardianSafePeriodActivateAt);
    }

    function _storeRawOwnerBytes(bytes32 slot, bytes memory data) internal {
        keyStoreStorage().setBytes(slot, "rawOwners", data);
    }

    function _getRawOwners(bytes32 slot) internal view returns (bytes memory rawOwners) {
        return keyStoreStorage().getBytes(slot, "rawOwners");
    }

    function _getGuardianInfo(bytes32 slot) internal view returns (guardianInfo memory _guardianInfo) {
        _guardianInfo.guardianHash = _getGuardianHash(slot);
        _guardianInfo.pendingGuardianHash = _getPendingGuardianHash(slot);
        _guardianInfo.guardianActivateAt = _getGuardianActivateAt(slot);
        _guardianInfo.guardianSafePeriod = _getGuardianSafePeriod(slot);
        _guardianInfo.pendingGuardianSafePeriod = _getPendingGuardianSafePeriod(slot);
        _guardianInfo.guardianSafePeriodActivateAt = _getGuardianSafePeriodActivateAt(slot);
    }

    function _getKeyStoreInfo(bytes32 slot) internal view returns (keyStoreInfo memory _keyStoreInfo) {
        _keyStoreInfo.key = _getKey(slot);
        _keyStoreInfo.nonce = _getNonce(slot);
        _keyStoreInfo.guardianHash = _getGuardianHash(slot);
        _keyStoreInfo.pendingGuardianHash = _getPendingGuardianHash(slot);
        _keyStoreInfo.guardianActivateAt = _getGuardianActivateAt(slot);
        _keyStoreInfo.guardianSafePeriod = _getGuardianSafePeriod(slot);
        _keyStoreInfo.pendingGuardianSafePeriod = _getPendingGuardianSafePeriod(slot);
        _keyStoreInfo.guardianSafePeriodActivateAt = _getGuardianSafePeriodActivateAt(slot);
    }

    function _setGuardianInfo(bytes32 slot, guardianInfo memory _info) internal {
        _setGuardianHash(slot, _info.guardianHash);
        _setPendingGuardianHash(slot, _info.pendingGuardianHash);
        _setGuardianActivateAt(slot, _info.guardianActivateAt);
        _setGuardianSafePeriod(slot, _info.guardianSafePeriod);
        _setPendingGuardianSafePeriod(slot, _info.pendingGuardianSafePeriod);
        _setGuardianSafePeriodActivateAt(slot, _info.guardianSafePeriodActivateAt);
    }

    function _setkeyStoreInfo(bytes32 slot, keyStoreInfo memory _info) internal {
        _saveKey(slot, _info.key);
        _setGuardianHash(slot, _info.guardianHash);
        _setPendingGuardianHash(slot, _info.pendingGuardianHash);
        _setGuardianActivateAt(slot, _info.guardianActivateAt);
        _setGuardianSafePeriod(slot, _info.guardianSafePeriod);
        _setPendingGuardianSafePeriod(slot, _info.pendingGuardianSafePeriod);
        _setGuardianSafePeriodActivateAt(slot, _info.guardianSafePeriodActivateAt);
    }
}
