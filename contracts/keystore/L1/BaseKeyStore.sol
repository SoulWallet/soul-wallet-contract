// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./KeyStoreStorage.sol";
import "../../libraries/KeyStoreSlotLib.sol";

abstract contract BaseKeyStore is IKeyStore, KeyStoreStorage {
    function _validateKeySignature(bytes32 key, bytes32 signHash, bytes calldata keySignature) internal virtual;

    function _validateKeySignature(bytes32 slot, bytes32 key, bytes32 data, bytes calldata keySignature) private {
        bytes32 signHash = _getSignHash(slot, _getNonce(slot), data);
        _validateKeySignature(key, signHash, keySignature);
        _increaseNonce(slot);
    }

    function _validateGuardianSignature(
        bytes32 guardianHash,
        bytes calldata rawGuardian,
        bytes32 signHash,
        bytes calldata keySignature
    ) internal virtual;

    function _validateGuardianSignature(
        bytes32 slot,
        bytes32 guardianHash,
        bytes calldata rawGuardian,
        bytes32 data,
        bytes calldata keySignature
    ) private {
        bytes32 signHash = _getSignHash(slot, _getNonce(slot), data);
        _validateGuardianSignature(guardianHash, rawGuardian, signHash, keySignature);
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

    function _getSignHash(bytes32 slot, uint256 _nonce, bytes32 data) private view returns (bytes32 validateHash) {
        /*
            Why chainId not in the signature?
             - Removing the chainId essentially allows the signature to be replayed in multiple Layer1s, 
               which may give us the feature of consistent multi-Layer1 addresses.
         */
        return keccak256(abi.encode(address(this), slot, _nonce, data));
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
        _validateKeySignature(slot, signKey, newKey, keySignature);
        _saveKey(slot, newKey);
    }

    function setKey(bytes32 slot, bytes32 newKey, bytes calldata keySignature)
        external
        override
        onlyInitialized(slot)
    {
        bytes32 signKey = _getKey(slot);
        _setKey(slot, signKey, newKey, keySignature);
    }

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

        _validateGuardianSignature(slot, _getGuardianInfo(slot).guardianHash, rawGuardian, newKey, guardianSignature);

        _saveKey(slot, newKey);
    }

    function setKey(bytes32 slot, bytes32 newKey, bytes calldata rawGuardian, bytes calldata guardianSignature)
        external
        override
    {
        _autoSetupGuardian(slot);

        _validateGuardianSignature(slot, _getGuardianInfo(slot).guardianHash, rawGuardian, newKey, guardianSignature);
        _saveKey(slot, newKey);
    }

    function getKeyStoreInfo(bytes32 slot) external pure override returns (keyStoreInfo memory _keyStoreInfo) {
        return _getkeyStoreInfo(slot);
    }

    function _getGuardianHash(bytes calldata rawGuardian) private pure returns (bytes32 guardianHash) {
        return keccak256(rawGuardian);
    }

    function getGuardianHash(bytes calldata rawGuardian) external pure override returns (bytes32 guardianHash) {
        return _getGuardianHash(rawGuardian);
    }

    function setGuardian(bytes32 slot, bytes32 newGuardianHash, bytes calldata keySignature) external override {
        _autoSetupGuardian(slot);

        bytes32 signKey = _getKey(slot);
        _validateKeySignature(slot, signKey, newGuardianHash, keySignature);
        guardianInfo storage _guardianInfo = _getGuardianInfo(slot);
        _guardianInfo.pendingGuardianHash = newGuardianHash;

        uint64 _guardianActivateAt = uint64(block.timestamp) + _guardianInfo.guardianSafePeriod;
        _guardianInfo.guardianActivateAt = _guardianActivateAt;

        emit SetGuardian(slot, newGuardianHash, _guardianActivateAt);
    }

    function setGuardian(
        bytes32 initialKey,
        bytes32 initialGuardianHash,
        uint64 initialGuardianSafePeriod,
        bytes32 newGuardianHash,
        bytes calldata keySignature
    ) external override {
        (bytes32 slot, bytes32 key) = _init(initialKey, initialGuardianHash, initialGuardianSafePeriod);
        _autoSetupGuardian(slot);

        _validateKeySignature(slot, key, newGuardianHash, keySignature);
        guardianInfo storage _guardianInfo = _getGuardianInfo(slot);
        _guardianInfo.pendingGuardianHash = newGuardianHash;

        uint64 _guardianActivateAt = uint64(block.timestamp) + _guardianInfo.guardianSafePeriod;
        _guardianInfo.guardianActivateAt = _guardianActivateAt;

        emit SetGuardian(slot, newGuardianHash, _guardianActivateAt);
    }

    function cancelSetGuardian(bytes32 slot, bytes calldata keySignature) external override {
        _autoSetupGuardian(slot);

        bytes32 signKey = _getKey(slot);
        _validateKeySignature(slot, signKey, bytes32(0), keySignature);
        guardianInfo storage _guardianInfo = _getGuardianInfo(slot);

        emit CancelSetGuardian(slot, _guardianInfo.pendingGuardianHash);

        _guardianInfo.pendingGuardianHash = bytes32(0);
        _guardianInfo.guardianActivateAt = 0;
    }

    function setGuardianSafePeriod(bytes32 slot, uint64 newGuardianSafePeriod, bytes calldata keySignature)
        external
        override
    {
        _autoSetupGuardian(slot);

        _guardianSafePeriodGuard(newGuardianSafePeriod);
        bytes32 _newGuardianSafePeriod = bytes32(uint256(newGuardianSafePeriod));
        bytes32 signKey = _getKey(slot);
        _validateKeySignature(slot, signKey, _newGuardianSafePeriod, keySignature);
        guardianInfo storage _guardianInfo = _getGuardianInfo(slot);
        _guardianInfo.pendingGuardianSafePeriod = newGuardianSafePeriod;
        uint64 _guardianSafePeriodActivateAt = uint64(block.timestamp) + _guardianInfo.guardianSafePeriod;
        _guardianInfo.guardianSafePeriodActivateAt = _guardianSafePeriodActivateAt;
        emit SetGuardianSafePeriod(slot, newGuardianSafePeriod, _guardianSafePeriodActivateAt);
    }

    /*
     * @dev pre change guardian safe period
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
        _validateKeySignature(slot, signKey, _newGuardianSafePeriod, keySignature);
        guardianInfo storage _guardianInfo = _getGuardianInfo(slot);
        _guardianInfo.pendingGuardianSafePeriod = newGuardianSafePeriod;
        uint64 _guardianSafePeriodActivateAt = uint64(block.timestamp) + _guardianInfo.guardianSafePeriod;
        _guardianInfo.guardianSafePeriodActivateAt = _guardianSafePeriodActivateAt;

        emit SetGuardianSafePeriod(slot, newGuardianSafePeriod, _guardianSafePeriodActivateAt);
    }

    function cancelSetGuardianSafePeriod(bytes32 slot, bytes calldata keySignature)
        external
        override
        onlyInitialized(slot)
    {
        _autoSetupGuardian(slot);

        bytes32 signKey = _getKey(slot);
        _validateKeySignature(slot, signKey, bytes32(0), keySignature);
        guardianInfo storage _guardianInfo = _getGuardianInfo(slot);

        emit CancelSetGuardianSafePeriod(slot, _guardianInfo.pendingGuardianSafePeriod);

        _guardianInfo.pendingGuardianSafePeriod = 0;
        _guardianInfo.guardianSafePeriodActivateAt = 0;
    }
}
