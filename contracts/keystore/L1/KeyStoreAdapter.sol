// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "./interfaces/IKeyStoreStorage.sol";
import "./interfaces/IKeyStore.sol";
import "../../libraries/Errors.sol";

/**
 * @title KeyStoreAdapter
 * @dev A contract that provides a set of utility functions to interact with a keystore
 */
abstract contract KeyStoreAdapter is IKeyStore {
    uint256 internal constant _GUARDIAN_PERIOD_MIN = 2 days;
    uint256 internal constant _GUARDIAN_PERIOD_MAX = 30 days;
    /**
     * @dev Returns the current instance of the KeyStoreStorage
     * This function should be implemented by derived contracts
     */

    function keyStoreStorage() public view virtual returns (IKeyStoreStorage);
    /**
     * @dev Fetches the current nonce for a given slot
     * @param slot The slot from which to fetch the nonce
     * @return _nonce The nonce of the given slot
     */

    function _getNonce(bytes32 slot) internal view returns (uint256 _nonce) {
        return keyStoreStorage().getUint256(slot, "nonce");
    }

    /**
     * @dev Increases the nonce of a given slot by one
     * @param slot The slot for which the nonce should be increased
     */
    function _increaseNonce(bytes32 slot) internal {
        uint256 _newNonce = _getNonce(slot) + 1;
        keyStoreStorage().setUint256(slot, "nonce", _newNonce);
    }

    /**
     * @dev Verifies that a given key is valid
     * @param key The key to be verified
     */
    function _keyGuard(bytes32 key) internal view virtual {
        if (key == bytes32(0)) {
            revert Errors.INVALID_KEY();
        }
    }

    /**
     * @dev Stores the signing key hash in a given slot
     * @param slot The slot in which the signing key hash should be stored
     * @param key the signing key hash to be stored
     */
    function _saveKey(bytes32 slot, bytes32 key) internal {
        _keyGuard(key);
        keyStoreStorage().setSlotValue(slot, key);
        emit KeyChanged(slot, key);
    }

    /**
     * @dev Fetches the signing key hash stored in a given slot
     * @param slot The slot from which to fetch the signing key hash
     * @return key The signing key hash stored in the given slot
     */
    function _getKey(bytes32 slot) internal view returns (bytes32 key) {
        return keyStoreStorage().getSlotValue(slot);
    }
    /**
     * @dev Fetches the guardian hash of a given slot
     * @param slot The slot from which to fetch the guardian hash
     * @return key The guardian hash of the given slot
     */

    function _getGuardianHash(bytes32 slot) internal view returns (bytes32 key) {
        return keyStoreStorage().getBytes32(slot, "guardianHash");
    }
    /**
     * @dev Sets the guardian hash for a given slot
     * @param slot The slot for which the guardian hash should be set
     * @param _guardianHash The guardian hash to set
     */

    function _setGuardianHash(bytes32 slot, bytes32 _guardianHash) internal {
        return keyStoreStorage().setBytes32(slot, "guardianHash", _guardianHash);
    }
    /**
     * @dev Fetches the pending guardian hash of a given slot
     * @param slot The slot from which to fetch the pending guardian hash
     * @return key The pending guardian hash of the given slot
     */

    function _getPendingGuardianHash(bytes32 slot) internal view returns (bytes32 key) {
        return keyStoreStorage().getBytes32(slot, "pendingGuardianHash");
    }
    /**
     * @dev Sets the pending guardian hash for a given slot
     * @param slot The slot for which the pending guardian hash should be set
     * @param _guardianHash The pending guardian hash to set
     */

    function _setPendingGuardianHash(bytes32 slot, bytes32 _guardianHash) internal {
        return keyStoreStorage().setBytes32(slot, "pendingGuardianHash", _guardianHash);
    }
    /**
     * @dev Fetches the guardian activation time for a given slot
     * @param slot The slot from which to fetch the guardian activation time
     * @return The guardian activation time of the given slot
     */

    function _getGuardianActivateAt(bytes32 slot) internal view returns (uint256) {
        return keyStoreStorage().getUint256(slot, "guardianActivateAt");
    }
    /**
     * @dev Sets the guardian activation time for a given slot
     * @param slot The slot for which the guardian activation time should be set
     * @param _guardianActiveAt The guardian activation time to set
     */

    function _setGuardianActivateAt(bytes32 slot, uint256 _guardianActiveAt) internal {
        return keyStoreStorage().setUint256(slot, "guardianActivateAt", _guardianActiveAt);
    }
    /**
     * @dev Fetches the guardian safe period for a given slot
     * @param slot The slot from which to fetch the guardian safe period
     * @return The guardian safe period of the given slot
     */

    function _getGuardianSafePeriod(bytes32 slot) internal view returns (uint256) {
        return keyStoreStorage().getUint256(slot, "guardianSafePeriod");
    }
    /**
     * @dev Sets the guardian safe period for a given slot
     * @param slot The slot for which the guardian safe period should be set
     * @param _guardianSafePeriod The guardian safe period to set
     */

    function _setGuardianSafePeriod(bytes32 slot, uint256 _guardianSafePeriod) internal {
        keyStoreStorage().setUint256(slot, "guardianSafePeriod", _guardianSafePeriod);
    }
    /**
     * @dev Fetches the pending guardian safe period for a given slot
     * @param slot The slot from which to fetch the pending guardian safe period
     * @return The pending guardian safe period of the given slot
     */

    function _getPendingGuardianSafePeriod(bytes32 slot) internal view returns (uint256) {
        return keyStoreStorage().getUint256(slot, "pendingGuardianSafePeriod");
    }
    /**
     * @dev Sets the pending guardian safe period for a given slot
     * @param slot The slot for which the pending guardian safe period should be set.
     * @param _pendingGuardianSafePeriod The pending guardian safe period to set.
     */

    function _setPendingGuardianSafePeriod(bytes32 slot, uint256 _pendingGuardianSafePeriod) internal {
        keyStoreStorage().setUint256(slot, "pendingGuardianSafePeriod", _pendingGuardianSafePeriod);
    }
    /**
     * @dev Fetches the guardian safe period activation time for a given slot
     * @param slot The slot from which to fetch the guardian safe period activation time
     * @return The guardian safe period activation time of the given slot
     */

    function _getGuardianSafePeriodActivateAt(bytes32 slot) internal view returns (uint256) {
        return keyStoreStorage().getUint256(slot, "guardianSafePeriodActivateAt");
    }
    /**
     * @dev Sets the guardian safe period activation time for a given slot
     * @param slot The slot for which the guardian safe period activation time should be set
     * @param _guardianSafePeriodActivateAt The guardian safe period activation time to set
     */

    function _setGuardianSafePeriodActivateAt(bytes32 slot, uint256 _guardianSafePeriodActivateAt) internal {
        keyStoreStorage().setUint256(slot, "guardianSafePeriodActivateAt", _guardianSafePeriodActivateAt);
    }
    /**
     * @dev Stores raw owner bytes for a given slot
     * @param slot The slot in which the raw owner bytes should be stored
     * @param data The raw owner bytes to store
     */

    function _storeRawOwnerBytes(bytes32 slot, bytes memory data) internal {
        keyStoreStorage().setBytes(slot, "rawOwners", data);
    }
    /**
     * @dev Fetches the raw owner's bytes for a given slot
     * @param slot The slot from which to fetch the raw owner's bytes
     * @return rawOwners The raw owner's bytes of the given slot
     */

    function _getRawOwners(bytes32 slot) internal view returns (bytes memory rawOwners) {
        return keyStoreStorage().getBytes(slot, "rawOwners");
    }
    /**
     * @dev Fetches guardian info for a given slot
     * @param slot The slot from which to fetch the guardian info
     * @return _guardianInfo The guardian info of the given slot
     */

    function _getGuardianInfo(bytes32 slot) internal view returns (guardianInfo memory _guardianInfo) {
        _guardianInfo.guardianHash = _getGuardianHash(slot);
        _guardianInfo.pendingGuardianHash = _getPendingGuardianHash(slot);
        _guardianInfo.guardianActivateAt = _getGuardianActivateAt(slot);
        _guardianInfo.guardianSafePeriod = _getGuardianSafePeriod(slot);
        _guardianInfo.pendingGuardianSafePeriod = _getPendingGuardianSafePeriod(slot);
        _guardianInfo.guardianSafePeriodActivateAt = _getGuardianSafePeriodActivateAt(slot);
    }
    /**
     * @dev Fetches keystore info for a given slot
     * @param slot The slot from which to fetch the keystore info
     * @return _keyStoreInfo The keystore info of the given slot
     */

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
    /**
     * @dev Sets the guardian info for a given slot
     * @param slot The slot for which the guardian info should be set
     * @param _info The guardian info to set
     */

    function _setGuardianInfo(bytes32 slot, guardianInfo memory _info) internal {
        _setGuardianHash(slot, _info.guardianHash);
        _setPendingGuardianHash(slot, _info.pendingGuardianHash);
        _setGuardianActivateAt(slot, _info.guardianActivateAt);
        _setGuardianSafePeriod(slot, _info.guardianSafePeriod);
        _setPendingGuardianSafePeriod(slot, _info.pendingGuardianSafePeriod);
        _setGuardianSafePeriodActivateAt(slot, _info.guardianSafePeriodActivateAt);
    }
    /**
     * @dev Sets the keystore info for a given slot
     * @param slot The slot for which the keystore info should be set
     * @param _info The keystore info to set
     */

    function _setkeyStoreInfo(bytes32 slot, keyStoreInfo memory _info) internal {
        _saveKey(slot, _info.key);
        _setGuardianHash(slot, _info.guardianHash);
        _setPendingGuardianHash(slot, _info.pendingGuardianHash);
        _setGuardianActivateAt(slot, _info.guardianActivateAt);
        _setGuardianSafePeriod(slot, _info.guardianSafePeriod);
        _setPendingGuardianSafePeriod(slot, _info.pendingGuardianSafePeriod);
        _setGuardianSafePeriodActivateAt(slot, _info.guardianSafePeriodActivateAt);
    }

    /**
     * @dev Sets the keystore logic address for a given slot
     * @param slot The slot for which the logic address should be set
     * @param newLogicAddress The new logic address
     */
    function _setKeyStoreLogic(bytes32 slot, address newLogicAddress) internal {
        keyStoreStorage().setKeystoreLogic(slot, newLogicAddress);
    }
}
