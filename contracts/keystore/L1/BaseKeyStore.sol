// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "./KeyStoreAdapter.sol";
import "../../libraries/KeyStoreSlotLib.sol";

abstract contract BaseKeyStore is IKeyStore, KeyStoreAdapter {
    /**
     * @notice Verify the signature of the `signKey`
     * @dev Implementers must revert if the signature is invalid
     * @param slot The KeyStore slot
     * @param slotNonce Used to prevent replay attacks
     * @param signKey The current sign key
     * @param action The action type
     * @param data Data associated with the action
     * @param rawOwners Raw owner data
     * @param keySignature Signature of the current sign key
     */
    function verifySignature(
        bytes32 slot,
        uint256 slotNonce,
        bytes32 signKey,
        Action action,
        bytes32 data,
        bytes memory rawOwners,
        bytes memory keySignature
    ) internal virtual;

    /**
     * @notice Verify the signature of the `guardian`
     * @param slot The KeyStore slot
     * @param slotNonce Used to prevent replay attacks
     * @param rawGuardian The raw data of the `guardianHash`
     * @param newKey The new key
     * @param guardianSignature Signature of the guardians
     */
    function verifyGuardianSignature(
        bytes32 slot,
        uint256 slotNonce,
        bytes calldata rawGuardian,
        bytes32 newKey,
        bytes calldata guardianSignature
    ) internal virtual;

    function _verifySignature(
        bytes32 slot,
        bytes32 signKey,
        Action action,
        bytes32 data,
        bytes memory rawOwners,
        bytes memory keySignature
    ) private {
        verifySignature(slot, _getNonce(slot), signKey, action, data, rawOwners, keySignature);
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
    /**
     * @notice View the nonce associated with a slot
     * @param slot The KeyStore slot
     * @return _nonce The nonce
     */

    function nonce(bytes32 slot) external view override returns (uint256 _nonce) {
        return _getNonce(slot);
    }

    function _getSlot(bytes32 initialKeyHash, bytes32 initialGuardianHash, uint256 guardianSafePeriod)
        private
        pure
        returns (bytes32 slot)
    {
        return KeyStoreSlotLib.getSlot(initialKeyHash, initialGuardianHash, guardianSafePeriod);
    }
    /**
     * @notice Calculate and retrieve the slot based on provided initial values
     * @param initialKeyHash The initial key hash
     * @param initialGuardianHash The initial guardian hash
     * @param guardianSafePeriod The guardian safe period
     * @return slot The KeyStore slot
     */

    function getSlot(bytes32 initialKeyHash, bytes32 initialGuardianHash, uint256 guardianSafePeriod)
        external
        pure
        override
        returns (bytes32 slot)
    {
        return _getSlot(initialKeyHash, initialGuardianHash, guardianSafePeriod);
    }

    /**
     * @notice View the key associated with a slot
     * @param slot The KeyStore slot
     * @return key The key
     */
    function getKey(bytes32 slot) external view override returns (bytes32 key) {
        return _getKey(slot);
    }

    modifier onlyInitialized(bytes32 slot) {
        if (_getKey(slot) == bytes32(0)) {
            revert Errors.NOT_INITIALIZED();
        }
        _;
    }

    function _guardianSafePeriodGuard(uint256 safePeriodGuard) private pure {
        if (safePeriodGuard < _GUARDIAN_PERIOD_MIN || safePeriodGuard > _GUARDIAN_PERIOD_MAX) {
            revert Errors.INVALID_TIME_RANGE();
        }
    }

    function _autoSetupGuardian(bytes32 slot) private onlyInitialized(slot) {
        guardianInfo memory _guardianInfo = _getGuardianInfo(slot);
        require(_guardianInfo.guardianSafePeriod > 0);

        uint256 nowTime = uint256(block.timestamp);
        if (_guardianInfo.guardianActivateAt > 0 && _guardianInfo.guardianActivateAt <= nowTime) {
            bytes32 _pendingGuardianHash = _guardianInfo.pendingGuardianHash;
            _guardianInfo.guardianHash = _pendingGuardianHash;
            _guardianInfo.guardianActivateAt = 0;
            _guardianInfo.pendingGuardianHash = bytes32(0);
            _setGuardianInfo(slot, _guardianInfo);
            emit GuardianChanged(slot, _pendingGuardianHash);
        }
        if (_guardianInfo.guardianSafePeriodActivateAt > 0 && _guardianInfo.guardianSafePeriodActivateAt <= nowTime) {
            _guardianSafePeriodGuard(_guardianInfo.pendingGuardianSafePeriod);
            uint256 _pendingGuardianSafePeriod = _guardianInfo.pendingGuardianSafePeriod;
            _guardianInfo.guardianSafePeriod = _pendingGuardianSafePeriod;
            _guardianInfo.guardianSafePeriodActivateAt = 0;
            _guardianInfo.pendingGuardianSafePeriod = 0;
            _setGuardianInfo(slot, _guardianInfo);
            emit GuardianSafePeriodChanged(slot, _pendingGuardianSafePeriod);
        }
    }

    function _init(bytes32 initialKeyHash, bytes32 initialGuardianHash, uint256 initialGuardianSafePeriod)
        private
        returns (bytes32 slot, bytes32 key)
    {
        slot = _getSlot(initialKeyHash, initialGuardianHash, initialGuardianSafePeriod);
        key = _getKey(slot);
        if (key == bytes32(0)) {
            key = initialKeyHash;
            keyStoreInfo memory _keyStoreInfo = _getKeyStoreInfo(slot);
            _keyStoreInfo.key = initialKeyHash;
            _keyStoreInfo.guardianHash = initialGuardianHash;
            _guardianSafePeriodGuard(initialGuardianSafePeriod);
            _keyStoreInfo.guardianSafePeriod = initialGuardianSafePeriod;
            _setkeyStoreInfo(slot, _keyStoreInfo);
            emit Initialized(slot, key);
        }
    }

    function _setKey(
        bytes32 slot,
        bytes32 signKey,
        bytes calldata newRawOwners,
        bytes calldata currentRawOwners,
        bytes calldata keySignature
    ) private {
        bytes32 newKey = _getOwnersHash(newRawOwners);
        _verifySignature(slot, signKey, Action.SET_KEY, newKey, currentRawOwners, keySignature);
        _saveKey(slot, newKey);
        _storeRawOwnerBytes(slot, newRawOwners);
    }

    /**
     * @notice Set the key for a slot that is already initialized
     * @param slot The KeyStore slot
     * @param newRawOwners The new owners
     * @param currentRawOwners The current owners
     * @param keySignature Signature of the owners
     */
    function setKeyByOwner(
        bytes32 slot,
        bytes calldata newRawOwners,
        bytes calldata currentRawOwners,
        bytes calldata keySignature
    ) external override onlyInitialized(slot) {
        bytes32 signKey = _getKey(slot);
        _setKey(slot, signKey, newRawOwners, currentRawOwners, keySignature);
    }

    /**
     * @notice Set the key for a slot that is not yet initialized
     * @param initialKeyHash The initial key hash
     * @param initialGuardianHash The initial guardian hash
     * @param initialGuardianSafePeriod The initial guardian safe period
     * @param newRawOwners The new owners
     * @param currentRawOwners The current owners
     * @param keySignature One of the current owners' signature
     */
    function setKeyByOwner(
        bytes32 initialKeyHash,
        bytes32 initialGuardianHash,
        uint256 initialGuardianSafePeriod,
        bytes calldata newRawOwners,
        bytes calldata currentRawOwners,
        bytes calldata keySignature
    ) external override {
        (bytes32 slot, bytes32 key) = _init(initialKeyHash, initialGuardianHash, initialGuardianSafePeriod);
        _setKey(slot, key, newRawOwners, currentRawOwners, keySignature);
    }

    /**
     * @notice Set the key for a slot using social recovery
     * @param initialKeyHash The initial key hash
     * @param initialGuardianHash The initial guardian hash
     * @param initialGuardianSafePeriod The initial guardian safe period
     * @param newRawOwners The new owners
     * @param rawGuardian Raw guardian data
     * @param guardianSignature Signature of the initial guardians
     */
    function setKeyByGuardian(
        bytes32 initialKeyHash,
        bytes32 initialGuardianHash,
        uint256 initialGuardianSafePeriod,
        bytes calldata newRawOwners,
        bytes calldata rawGuardian,
        bytes calldata guardianSignature
    ) external override {
        bytes32 newKey = _getOwnersHash(newRawOwners);
        (bytes32 slot,) = _init(initialKeyHash, initialGuardianHash, initialGuardianSafePeriod);
        _autoSetupGuardian(slot);
        _verifyGuardianSignature(slot, rawGuardian, newKey, guardianSignature);
        _saveKey(slot, newKey);
        _storeRawOwnerBytes(slot, newRawOwners);
    }

    /**
     * @notice Social recovery to change the key using the guardian's signature
     * @dev Only works for initialized slots
     * @param slot The KeyStore slot identifier
     * @param newRawOwners The new raw owner data
     * @param rawGuardian The raw data of the guardian
     * @param guardianSignature The signature of the guardians
     */
    function setKeyByGuardian(
        bytes32 slot,
        bytes calldata newRawOwners,
        bytes calldata rawGuardian,
        bytes calldata guardianSignature
    ) external override {
        bytes32 newKey = _getOwnersHash(newRawOwners);
        _autoSetupGuardian(slot);
        _verifyGuardianSignature(slot, rawGuardian, newKey, guardianSignature);
        _saveKey(slot, newKey);
        _storeRawOwnerBytes(slot, newRawOwners);
    }

    /**
     * @notice Fetches all the data stored in a KeyStore slot
     * @param slot The KeyStore slot identifier
     * @return _keyStoreInfo The keyStoreInfo struct with all the data from the slot
     */
    function getKeyStoreInfo(bytes32 slot) external view override returns (keyStoreInfo memory _keyStoreInfo) {
        return _getKeyStoreInfo(slot);
    }

    function _getGuardianHash(bytes memory rawGuardian) internal pure returns (bytes32 guardianHash) {
        return keccak256(rawGuardian);
    }

    function _getOwnersHash(bytes memory rawOwners) internal pure returns (bytes32 key) {
        return keccak256(rawOwners);
    }

    /**
     * @notice Computes the hash of a raw guardian data
     * @param rawGuardian The raw data of the guardian
     * @return guardianHash The computed hash of the provided guardian data
     */
    function getGuardianHash(bytes memory rawGuardian) external pure override returns (bytes32 guardianHash) {
        return _getGuardianHash(rawGuardian);
    }

    /**
     * @notice Computes the key hash from raw owner data
     * @param rawOwners The raw owner data
     * @return key The computed key hash
     */
    function getOwnersKeyHash(bytes memory rawOwners) external pure override returns (bytes32 key) {
        return _getOwnersHash(rawOwners);
    }

    /**
     * @notice Change the guardian hash for a given KeyStore slot
     * @dev Only works for initialized slots
     * @param slot The KeyStore slot identifier
     * @param newGuardianHash The new guardian hash
     * @param rawOwners The raw owner data
     * @param keySignature The signature of the owner key
     */
    function setGuardian(bytes32 slot, bytes32 newGuardianHash, bytes calldata rawOwners, bytes calldata keySignature)
        external
        override
    {
        _autoSetupGuardian(slot);

        bytes32 signKey = _getKey(slot);
        _verifySignature(slot, signKey, Action.SET_GUARDIAN, newGuardianHash, rawOwners, keySignature);

        guardianInfo memory _guardianInfo = _getGuardianInfo(slot);
        _guardianInfo.pendingGuardianHash = newGuardianHash;

        uint256 _guardianActivateAt = uint256(block.timestamp) + _guardianInfo.guardianSafePeriod;
        _guardianInfo.guardianActivateAt = _guardianActivateAt;
        _setGuardianInfo(slot, _guardianInfo);

        emit SetGuardian(slot, newGuardianHash, _guardianActivateAt);
    }

    /**
     * @notice Change the guardian hash for a KeyStore slot using initialization data
     * @dev for slots that are not initialized
     * @param initialKeyHash The initial key hash
     * @param initialGuardianHash The initial guardian hash
     * @param initialGuardianSafePeriod The initial guardian safe period duration
     * @param newGuardianHash The new guardian hash
     * @param rawOwners The raw owner data
     * @param keySignature A signature from one of the current owners
     */
    function setGuardian(
        bytes32 initialKeyHash,
        bytes32 initialGuardianHash,
        uint256 initialGuardianSafePeriod,
        bytes32 newGuardianHash,
        bytes calldata rawOwners,
        bytes calldata keySignature
    ) external override {
        (bytes32 slot, bytes32 signKey) = _init(initialKeyHash, initialGuardianHash, initialGuardianSafePeriod);
        _autoSetupGuardian(slot);

        _verifySignature(slot, signKey, Action.SET_GUARDIAN, newGuardianHash, rawOwners, keySignature);
        guardianInfo memory _guardianInfo = _getGuardianInfo(slot);
        _guardianInfo.pendingGuardianHash = newGuardianHash;

        uint256 _guardianActivateAt = uint256(block.timestamp) + _guardianInfo.guardianSafePeriod;
        _guardianInfo.guardianActivateAt = _guardianActivateAt;
        _setGuardianInfo(slot, _guardianInfo);
        emit SetGuardian(slot, newGuardianHash, _guardianActivateAt);
    }

    /**
     * @notice Cancels a pending change of the guardian hash for a given KeyStore slot
     * @param slot The KeyStore slot identifier
     * @param rawOwners The raw owner data
     * @param keySignature The signature of the current key
     */
    function cancelSetGuardian(bytes32 slot, bytes calldata rawOwners, bytes calldata keySignature) external override {
        _autoSetupGuardian(slot);

        bytes32 signKey = _getKey(slot);
        _verifySignature(slot, signKey, Action.CANCEL_SET_GUARDIAN, bytes32(0), rawOwners, keySignature);
        guardianInfo memory _guardianInfo = _getGuardianInfo(slot);

        emit CancelSetGuardian(slot, _guardianInfo.pendingGuardianHash);

        _guardianInfo.pendingGuardianHash = bytes32(0);
        _guardianInfo.guardianActivateAt = 0;
        _setGuardianInfo(slot, _guardianInfo);
    }

    /**
     * @notice Changes the guardian safe period for a given KeyStore slot
     * @dev using for initialized slots
     * @param slot The KeyStore slot identifier
     * @param newGuardianSafePeriod The new duration of the guardian safe period
     * @param rawOwners The raw owner data
     * @param keySignature The signature of the current key
     */
    function setGuardianSafePeriod(
        bytes32 slot,
        uint256 newGuardianSafePeriod,
        bytes calldata rawOwners,
        bytes calldata keySignature
    ) external override {
        _autoSetupGuardian(slot);

        _guardianSafePeriodGuard(newGuardianSafePeriod);
        bytes32 _newGuardianSafePeriod = bytes32(uint256(newGuardianSafePeriod));
        bytes32 signKey = _getKey(slot);
        _verifySignature(
            slot, signKey, Action.SET_GUARDIAN_SAFE_PERIOD, _newGuardianSafePeriod, rawOwners, keySignature
        );
        guardianInfo memory _guardianInfo = _getGuardianInfo(slot);
        _guardianInfo.pendingGuardianSafePeriod = newGuardianSafePeriod;
        uint256 _guardianSafePeriodActivateAt = uint256(block.timestamp) + _guardianInfo.guardianSafePeriod;
        _guardianInfo.guardianSafePeriodActivateAt = _guardianSafePeriodActivateAt;
        _setGuardianInfo(slot, _guardianInfo);
        emit SetGuardianSafePeriod(slot, newGuardianSafePeriod, _guardianSafePeriodActivateAt);
    }

    /**
     * @notice Changes the guardian safe period for a KeyStore slot using initialization data
     * @dev for slots that are not initialized
     * @param initialKeyHash The initial key hash
     * @param initialGuardianHash The initial guardian hash
     * @param initialGuardianSafePeriod The initial guardian safe period duration
     * @param newGuardianSafePeriod The new duration of the guardian safe period
     * @param rawOwners The raw owner data
     * @param keySignature A signature from one of the current owners
     */
    function setGuardianSafePeriod(
        bytes32 initialKeyHash,
        bytes32 initialGuardianHash,
        uint256 initialGuardianSafePeriod,
        uint256 newGuardianSafePeriod,
        bytes calldata rawOwners,
        bytes calldata keySignature
    ) external override {
        (bytes32 slot, bytes32 signKey) = _init(initialKeyHash, initialGuardianHash, initialGuardianSafePeriod);
        _autoSetupGuardian(slot);

        _guardianSafePeriodGuard(newGuardianSafePeriod);
        bytes32 _newGuardianSafePeriod = bytes32(uint256(newGuardianSafePeriod));
        _verifySignature(
            slot, signKey, Action.SET_GUARDIAN_SAFE_PERIOD, _newGuardianSafePeriod, rawOwners, keySignature
        );
        guardianInfo memory _guardianInfo = _getGuardianInfo(slot);
        _guardianInfo.pendingGuardianSafePeriod = newGuardianSafePeriod;
        uint256 _guardianSafePeriodActivateAt = uint256(block.timestamp) + _guardianInfo.guardianSafePeriod;
        _guardianInfo.guardianSafePeriodActivateAt = _guardianSafePeriodActivateAt;
        _setGuardianInfo(slot, _guardianInfo);

        emit SetGuardianSafePeriod(slot, newGuardianSafePeriod, _guardianSafePeriodActivateAt);
    }

    /**
     * @notice Cancels a pending change of the guardian safe period for a given KeyStore slot
     * @param slot The KeyStore slot identifier
     * @param rawOwners The raw owner data
     * @param keySignature The signature of the current key
     */
    function cancelSetGuardianSafePeriod(bytes32 slot, bytes calldata rawOwners, bytes calldata keySignature)
        external
        override
        onlyInitialized(slot)
    {
        _autoSetupGuardian(slot);

        bytes32 signKey = _getKey(slot);
        _verifySignature(slot, signKey, Action.CANCEL_SET_GUARDIAN_SAFE_PERIOD, bytes32(0), rawOwners, keySignature);
        guardianInfo memory _guardianInfo = _getGuardianInfo(slot);

        emit CancelSetGuardianSafePeriod(slot, _guardianInfo.pendingGuardianSafePeriod);

        _guardianInfo.pendingGuardianSafePeriod = 0;
        _guardianInfo.guardianSafePeriodActivateAt = 0;
        _setGuardianInfo(slot, _guardianInfo);
    }
}
