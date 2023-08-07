// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./KeyStoreStorage.sol";
import "../../libraries/KeyStoreSlotLib.sol";

abstract contract BaseKeyStore is IKeyStore, KeyStoreStorage {
    /**
     * @dev Verify the signature of the `signKey`
     * @param slot KeyStore slot
     * @param slotNonce used to prevent replay attack
     * @param signKey Current sign key
     * @param action Action type, See ./interfaces/IKeyStore.sol: enum Action
     * @param data {new key(Action.SET_KEY) | new guardian hash(Action.SET_GUARDIAN) | new guardian safe period(Action.SET_GUARDIAN_SAFE_PERIOD) | empty(Action.CANCEL_SET_GUARDIAN | Action.CANCEL_SET_GUARDIAN_SAFE_PERIOD )}
     * @param keySignature `signature of current sign key`
     *
     * Note Implementer must revert if the signature is invalid
     */
    function verifySignature(
        bytes32 slot,
        uint256 slotNonce,
        bytes32 signKey,
        Action action,
        bytes32 data,
        bytes calldata keySignature
    ) internal virtual;

    /**
     * @dev Verify the signature of the `guardian`
     * @param slot KeyStore slot
     * @param slotNonce used to prevent replay attack
     * @param rawGuardian The raw data of the `guardianHash`
     * @param newKey New key
     * @param guardianSignature `signature of current guardian`
     */
    function verifyGuardianSignature(
        bytes32 slot,
        uint256 slotNonce,
        bytes calldata rawGuardian,
        bytes32 newKey,
        bytes calldata guardianSignature
    ) internal virtual;

    function _verifySignature(bytes32 slot, bytes32 signKey, Action action, bytes32 data, bytes calldata keySignature)
        private
    {
        verifySignature(slot, _getNonce(slot), signKey, action, data, keySignature);
        _increaseNonce(slot);
    }

    function _verifyGuardianSignature(
        bytes32 slot,
        bytes calldata rawGuardian,
        bytes32 newKey,
        bytes calldata guardianSignature
    ) private {
        bytes32 _guardianHash = _getGuardianInfo(slot).guardianHash;
        if (_getGuardianHash(rawGuardian) != _guardianHash) {
            revert Errors.INVALID_DATA();
        }
        verifyGuardianSignature(slot, _getNonce(slot), rawGuardian, newKey, guardianSignature);
        _increaseNonce(slot);
    }

    function nonce(bytes32 slot) external view override returns (uint256 _nonce) {
        return _getNonce(slot);
    }

    function _getSlot(bytes32 initialKey, bytes32 initialGuardianHash, uint64 guardianSafePeriod)
        private
        pure
        returns (bytes32 slot)
    {
        return KeyStoreSlotLib.getSlot(initialKey, initialGuardianHash, guardianSafePeriod);
    }

    function getSlot(bytes32 initialKey, bytes32 initialGuardianHash, uint64 guardianSafePeriod)
        external
        pure
        override
        returns (bytes32 slot)
    {
        return _getSlot(initialKey, initialGuardianHash, guardianSafePeriod);
    }

    function getKey(bytes32 slot) external view override returns (bytes32 key) {
        return _getKey(slot);
    }

    modifier onlyInitialized(bytes32 slot) {
        if (_getKey(slot) == bytes32(0)) {
            revert Errors.NOT_INITIALIZED();
        }
        _;
    }

    function _guardianSafePeriodGuard(uint64 safePeriodGuard) private pure {
        if (safePeriodGuard < _GUARDIAN_PERIOD_MIN || safePeriodGuard > _GUARDIAN_PERIOD_MAX) {
            revert Errors.INVALID_TIME_RANGE();
        }
    }

    function _autoSetupGuardian(bytes32 slot) private onlyInitialized(slot) {
        guardianInfo storage _guardianInfo = _getGuardianInfo(slot);
        require(_guardianInfo.guardianSafePeriod > 0);

        uint64 nowTime = uint64(block.timestamp);
        if (_guardianInfo.guardianActivateAt > 0 && _guardianInfo.guardianActivateAt <= nowTime) {
            bytes32 _pendingGuardianHash = _guardianInfo.pendingGuardianHash;
            _guardianInfo.guardianHash = _pendingGuardianHash;
            _guardianInfo.guardianActivateAt = 0;
            _guardianInfo.pendingGuardianHash = bytes32(0);
            emit GuardianChanged(slot, _pendingGuardianHash);
        }
        if (_guardianInfo.guardianSafePeriodActivateAt > 0 && _guardianInfo.guardianSafePeriodActivateAt <= nowTime) {
            _guardianSafePeriodGuard(_guardianInfo.pendingGuardianSafePeriod);
            uint64 _pendingGuardianSafePeriod = _guardianInfo.pendingGuardianSafePeriod;
            _guardianInfo.guardianSafePeriod = _pendingGuardianSafePeriod;
            _guardianInfo.guardianSafePeriodActivateAt = 0;
            _guardianInfo.pendingGuardianSafePeriod = 0;
            emit GuardianSafePeriodChanged(slot, _pendingGuardianSafePeriod);
        }
    }

    function _init(bytes32 initialKey, bytes32 initialGuardianHash, uint64 initialGuardianSafePeriod)
        private
        returns (bytes32 slot, bytes32 key)
    {
        slot = _getSlot(initialKey, initialGuardianHash, initialGuardianSafePeriod);
        key = _getKey(slot);
        if (key == bytes32(0)) {
            key = initialKey;
            keyStoreInfo storage _keyStoreInfo = _getkeyStoreInfo(slot);
            _keyStoreInfo.key = initialKey;
            _keyStoreInfo.guardianHash = initialGuardianHash;
            _guardianSafePeriodGuard(initialGuardianSafePeriod);
            _keyStoreInfo.guardianSafePeriod = initialGuardianSafePeriod;

            emit Initialized(slot);
        }
    }

    function _setKey(bytes32 slot, bytes32 signKey, bytes32 newKey, bytes calldata keySignature) private {
        _verifySignature(slot, signKey, Action.SET_KEY, newKey, keySignature);
        _saveKey(slot, newKey);
    }

    /**
     * @dev Change the key (only slot initialized)
     * @param slot KeyStore slot
     * @param newKey New key
     * @param keySignature `signature of current key`
     */
    function setKey(bytes32 slot, bytes32 newKey, bytes calldata keySignature)
        external
        override
        onlyInitialized(slot)
    {
        bytes32 signKey = _getKey(slot);
        _setKey(slot, signKey, newKey, keySignature);
    }

    /**
     * @dev Change the key (only slot not initialized)
     * @param initialKey Initial key
     * @param initialGuardianHash Initial guardian hash
     * @param initialGuardianSafePeriod Initial guardian safe period
     * @param newKey New key
     * @param keySignature `signature of initial key`
     */
    function setKey(
        bytes32 initialKey,
        bytes32 initialGuardianHash,
        uint64 initialGuardianSafePeriod,
        bytes32 newKey,
        bytes calldata keySignature
    ) external override {
        (bytes32 slot, bytes32 key) = _init(initialKey, initialGuardianHash, initialGuardianSafePeriod);
        _setKey(slot, key, newKey, keySignature);
    }

    /**
     * @dev Social recovery, change the key (only slot not initialized)
     * @param initialKey Initial key
     * @param initialGuardianHash Initial guardian hash
     * @param initialGuardianSafePeriod Initial guardian safe period
     * @param newKey New key
     * @param rawGuardian `raw guardian data`
     * @param guardianSignature `signature of initialGuardian`
     */
    function setKey(
        bytes32 initialKey,
        bytes32 initialGuardianHash,
        uint64 initialGuardianSafePeriod,
        bytes32 newKey,
        bytes calldata rawGuardian,
        bytes calldata guardianSignature
    ) external override {
        (bytes32 slot,) = _init(initialKey, initialGuardianHash, initialGuardianSafePeriod);
        _autoSetupGuardian(slot);
        _verifyGuardianSignature(slot, rawGuardian, newKey, guardianSignature);
        _saveKey(slot, newKey);
    }

    /**
     * @dev Social recovery, change the key (only slot initialized)
     * @param slot KeyStore slot
     * @param newKey New key
     * @param rawGuardian `raw guardian data`
     * @param guardianSignature `signature of current guardian`
     */
    function setKey(bytes32 slot, bytes32 newKey, bytes calldata rawGuardian, bytes calldata guardianSignature)
        external
        override
    {
        _autoSetupGuardian(slot);
        _verifyGuardianSignature(slot, rawGuardian, newKey, guardianSignature);
        _saveKey(slot, newKey);
    }

    /**
     * @dev Get all data stored in the slot. See ./interfaces/IKeyStore.sol: struct keyStoreInfo
     * @param slot KeyStore slot
     */
    function getKeyStoreInfo(bytes32 slot) external pure override returns (keyStoreInfo memory _keyStoreInfo) {
        return _getkeyStoreInfo(slot);
    }

    function _getGuardianHash(bytes calldata rawGuardian) private pure returns (bytes32 guardianHash) {
        return keccak256(rawGuardian);
    }

    /**
     * @dev Get guardian hash from raw guardian data
     * @param rawGuardian `raw guardian data`
     */
    function getGuardianHash(bytes calldata rawGuardian) external pure override returns (bytes32 guardianHash) {
        return _getGuardianHash(rawGuardian);
    }

    /**
     * @dev Change guardian hash (only slot initialized)
     * @param slot KeyStore slot
     * @param newGuardianHash New guardian hash
     * @param keySignature `signature of current key`
     */
    function setGuardian(bytes32 slot, bytes32 newGuardianHash, bytes calldata keySignature) external override {
        _autoSetupGuardian(slot);

        bytes32 signKey = _getKey(slot);
        _verifySignature(slot, signKey, Action.SET_GUARDIAN, newGuardianHash, keySignature);

        guardianInfo storage _guardianInfo = _getGuardianInfo(slot);
        _guardianInfo.pendingGuardianHash = newGuardianHash;

        uint64 _guardianActivateAt = uint64(block.timestamp) + _guardianInfo.guardianSafePeriod;
        _guardianInfo.guardianActivateAt = _guardianActivateAt;

        emit SetGuardian(slot, newGuardianHash, _guardianActivateAt);
    }

    /**
     * @dev Change guardian hash (only slot not initialized)
     * @param initialKey Initial key
     * @param initialGuardianHash Initial guardian hash
     * @param initialGuardianSafePeriod Initial guardian safe period
     * @param newGuardianHash New guardian hash
     * @param keySignature `signature of initial key`
     */
    function setGuardian(
        bytes32 initialKey,
        bytes32 initialGuardianHash,
        uint64 initialGuardianSafePeriod,
        bytes32 newGuardianHash,
        bytes calldata keySignature
    ) external override {
        (bytes32 slot, bytes32 signKey) = _init(initialKey, initialGuardianHash, initialGuardianSafePeriod);
        _autoSetupGuardian(slot);

        _verifySignature(slot, signKey, Action.SET_GUARDIAN, newGuardianHash, keySignature);
        guardianInfo storage _guardianInfo = _getGuardianInfo(slot);
        _guardianInfo.pendingGuardianHash = newGuardianHash;

        uint64 _guardianActivateAt = uint64(block.timestamp) + _guardianInfo.guardianSafePeriod;
        _guardianInfo.guardianActivateAt = _guardianActivateAt;

        emit SetGuardian(slot, newGuardianHash, _guardianActivateAt);
    }

    /**
     * @dev Cancel the pending guardianHash change
     * @param slot KeyStore slot
     * @param keySignature `signature of current key`
     */
    function cancelSetGuardian(bytes32 slot, bytes calldata keySignature) external override {
        _autoSetupGuardian(slot);

        bytes32 signKey = _getKey(slot);
        _verifySignature(slot, signKey, Action.CANCEL_SET_GUARDIAN, bytes32(0), keySignature);
        guardianInfo storage _guardianInfo = _getGuardianInfo(slot);

        emit CancelSetGuardian(slot, _guardianInfo.pendingGuardianHash);

        _guardianInfo.pendingGuardianHash = bytes32(0);
        _guardianInfo.guardianActivateAt = 0;
    }

    /**
     * @dev Change guardian safe period (only slot initialized)
     * @param slot KeyStore slot
     * @param newGuardianSafePeriod New guardian safe period
     * @param keySignature `signature of current key`
     */
    function setGuardianSafePeriod(bytes32 slot, uint64 newGuardianSafePeriod, bytes calldata keySignature)
        external
        override
    {
        _autoSetupGuardian(slot);

        _guardianSafePeriodGuard(newGuardianSafePeriod);
        bytes32 _newGuardianSafePeriod = bytes32(uint256(newGuardianSafePeriod));
        bytes32 signKey = _getKey(slot);
        _verifySignature(slot, signKey, Action.SET_GUARDIAN_SAFE_PERIOD, _newGuardianSafePeriod, keySignature);
        guardianInfo storage _guardianInfo = _getGuardianInfo(slot);
        _guardianInfo.pendingGuardianSafePeriod = newGuardianSafePeriod;
        uint64 _guardianSafePeriodActivateAt = uint64(block.timestamp) + _guardianInfo.guardianSafePeriod;
        _guardianInfo.guardianSafePeriodActivateAt = _guardianSafePeriodActivateAt;
        emit SetGuardianSafePeriod(slot, newGuardianSafePeriod, _guardianSafePeriodActivateAt);
    }

    /**
     * @dev Change guardian safe period (only slot not initialized)
     * @param initialKey Initial key
     * @param initialGuardianHash Initial guardian hash
     * @param initialGuardianSafePeriod Initial guardian safe period
     * @param newGuardianSafePeriod New guardian safe period
     * @param keySignature `signature of initial key`
     */
    function setGuardianSafePeriod(
        bytes32 initialKey,
        bytes32 initialGuardianHash,
        uint64 initialGuardianSafePeriod,
        uint64 newGuardianSafePeriod,
        bytes calldata keySignature
    ) external override {
        (bytes32 slot, bytes32 signKey) = _init(initialKey, initialGuardianHash, initialGuardianSafePeriod);
        _autoSetupGuardian(slot);

        _guardianSafePeriodGuard(newGuardianSafePeriod);
        bytes32 _newGuardianSafePeriod = bytes32(uint256(newGuardianSafePeriod));
        _verifySignature(slot, signKey, Action.SET_GUARDIAN_SAFE_PERIOD, _newGuardianSafePeriod, keySignature);
        guardianInfo storage _guardianInfo = _getGuardianInfo(slot);
        _guardianInfo.pendingGuardianSafePeriod = newGuardianSafePeriod;
        uint64 _guardianSafePeriodActivateAt = uint64(block.timestamp) + _guardianInfo.guardianSafePeriod;
        _guardianInfo.guardianSafePeriodActivateAt = _guardianSafePeriodActivateAt;

        emit SetGuardianSafePeriod(slot, newGuardianSafePeriod, _guardianSafePeriodActivateAt);
    }

    /**
     * @dev Cancel the pending guardian safe period change
     * @param slot KeyStore slot
     * @param keySignature `signature of current key`
     */
    function cancelSetGuardianSafePeriod(bytes32 slot, bytes calldata keySignature)
        external
        override
        onlyInitialized(slot)
    {
        _autoSetupGuardian(slot);

        bytes32 signKey = _getKey(slot);
        _verifySignature(slot, signKey, Action.CANCEL_SET_GUARDIAN_SAFE_PERIOD, bytes32(0), keySignature);
        guardianInfo storage _guardianInfo = _getGuardianInfo(slot);

        emit CancelSetGuardianSafePeriod(slot, _guardianInfo.pendingGuardianSafePeriod);

        _guardianInfo.pendingGuardianSafePeriod = 0;
        _guardianInfo.guardianSafePeriodActivateAt = 0;
    }
}
