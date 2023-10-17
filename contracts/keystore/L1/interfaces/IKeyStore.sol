// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @dev Action of Signature
 */
enum Action
/**
 * @dev Set KeyStore.key to `new key`
 */
{
    SET_KEY,
    /**
     * @dev Set KeyStore.guardianHash to `new guardianHash`
     */
    SET_GUARDIAN,
    /**
     * @dev Cancel the pending guardianHash change
     */
    CANCEL_SET_GUARDIAN,
    /**
     * @dev Set KeyStore.guardianSafePeriod to `new guardianSafePeriod`
     */
    SET_GUARDIAN_SAFE_PERIOD,
    /**
     * @dev Cancel the pending guardianSafePeriod change
     */
    CANCEL_SET_GUARDIAN_SAFE_PERIOD,
    /**
     * @dev upgrade the keystore logic for slot
     */
    UPGRADE_KEYSTORE_LOGIC
}

interface IKeyStore {
    /* 
    #######################################################################################################################################
    #                                                                                                                                     #
    #     Why do we need `uint256 initialGuardianSafePeriod`?                                                                              #
    #         There are two implementations:                                                                                              #
    #          1. Set a fixed guardianSafePeriod for all users, such as 48 hours.                                                         #
    #          2. Provide the ability for each individual user to set their own guardianSafePeriod.                                       #
    #         Using a fixed guardianSafePeriod for all users may lead to future issues regarding availability and even security.          #
    #         This is especially true considering the diversity in social recovery scenarios in the future, as people in different        #
    #         regions may have different vacation habits (during which the guardian may be unable to respond to social recovery           #
    #         requests). Even centralized guardians may face similar issues, such as social recovery solution providers based on KYC,     # 
    #         where each service provider may have inconsistent response times.                                                           #
    #         Therefore, providing the option for each user to set their own independent guardianSafePeriod is necessary.                 #
    #                                                                                                                                     #
    #######################################################################################################################################
    */

    /**
     * @dev Emitted when the slot is initialized.
     */
    event Initialized(bytes32 indexed slot, bytes32 key);

    /**
     * @dev Emitted when `key` is changed in `slot`.
     */
    event KeyChanged(bytes32 indexed slot, bytes32 key);

    /**
     * @dev Emitted when PreSetGuardian is called.
     */
    event SetGuardian(bytes32 indexed slot, bytes32 guardianHash, uint256 effectAt);

    /**
     * @dev Emitted when `guardianHash` is changed in `slot`.
     */
    event GuardianChanged(bytes32 indexed slot, bytes32 guardianHash);

    /**
     * @dev Emitted when CancelSetGuardian is called.
     */
    event CancelSetGuardian(bytes32 indexed slot, bytes32 guardianHash);

    /**
     * @dev Emitted when PreSetGuardianSafePeriod is called.
     */
    event SetGuardianSafePeriod(bytes32 indexed slot, uint256 guardianSafePeriod, uint256 effectAt);

    /**
     * @dev Emitted when `guardianSafePeriod` is changed in `slot`.
     */
    event GuardianSafePeriodChanged(bytes32 indexed slot, uint256 guardianSafePeriod);

    /**
     * @dev Emitted when CancelSetGuardianSafePeriod is called.
     */
    event CancelSetGuardianSafePeriod(bytes32 indexed slot, uint256 guardianSafePeriod);

    struct keyStoreInfo {
        /*
        key is the hash of the list of owners calcuated by using keccask256(abi.encode(owners))
         */
        bytes32 key;
        // prevent replay attack
        uint256 nonce;
        // guardian now
        bytes32 guardianHash;
        // guardian next
        bytes32 pendingGuardianHash;
        // `guardian next` effective time
        uint256 guardianActivateAt;
        // guardian safe period (in seconds)    48 hours <= guardianSafePeriod <= 30 days
        uint256 guardianSafePeriod;
        // guardian safe period next
        uint256 pendingGuardianSafePeriod;
        // `guardian safe period next` effective time
        uint256 guardianSafePeriodActivateAt;
    }

    /**
     * @dev guardian info
     */
    struct guardianInfo {
        // guardian now
        bytes32 guardianHash;
        // guardian next
        bytes32 pendingGuardianHash;
        // `guardian next` effective time
        uint256 guardianActivateAt;
        // guardian safe period (in seconds)    48 hours <= guardianSafePeriod <= 30 days
        uint256 guardianSafePeriod;
        // guardian safe period next
        uint256 pendingGuardianSafePeriod;
        // `guardian safe period next` effective time
        uint256 guardianSafePeriodActivateAt;
    }

    /**
     * @dev get keyStore nonce
     */
    function nonce(bytes32 slot) external view returns (uint256 _nonce);

    /**
     * @dev calculate slot
     */
    function getSlot(bytes32 initialKeyHash, bytes32 initialGuardianHash, uint256 initialGuardianSafePeriod)
        external
        pure
        returns (bytes32 slot);

    /**
     * @dev calculate guardian hash
     */
    function getGuardianHash(bytes calldata rawGuardian) external pure returns (bytes32 guardianHash);

    /**
     * @dev calculate key hash
     */
    function getOwnersKeyHash(bytes calldata rawOwners) external pure returns (bytes32 key);

    /**
     * @dev get key is saved in slot
     */
    function getKey(bytes32 slot) external view returns (bytes32 key);

    /**
     * @dev change key
     * @param keySignature `signature of old key`
     */
    function setKeyByOwner(
        bytes32 slot,
        bytes calldata newRawOwners,
        bytes calldata currentRawOwners,
        bytes calldata keySignature
    ) external;

    /**
     * @dev change key
     * @param keySignature `signature of old key`
     */
    function setKeyByOwner(
        bytes32 initialKeyHash,
        bytes32 initialGuardianHash,
        uint256 initialGuardianSafePeriod,
        bytes calldata newRawOwners,
        bytes calldata currentRawOwners,
        bytes calldata keySignature
    ) external;

    /**
     * @dev social recovery
     * @param guardianSignature `signature of guardian`
     */
    function setKeyByGuardian(
        bytes32 initialKeyHash,
        bytes32 initialGuardianHash,
        uint256 initialGuardianSafePeriod,
        bytes calldata newRawOwners,
        bytes calldata rawGuardian,
        bytes calldata guardianSignature
    ) external;

    /**
     * @dev social recovery
     * @param guardianSignature `signature of guardian`
     */
    function setKeyByGuardian(
        bytes32 slot,
        bytes calldata newRawOwners,
        bytes calldata rawGuardian,
        bytes calldata guardianSignature
    ) external;

    /**
     * @dev get keyStore data
     */
    function getKeyStoreInfo(bytes32 slot) external view returns (keyStoreInfo memory _keyStoreInfo);

    /*
     * @dev pre change guardian
     */
    function setGuardian(bytes32 slot, bytes32 newGuardianHash, bytes calldata rawOwners, bytes calldata keySignature)
        external;

    /*
     * @dev pre change guardian
     */
    function setGuardian(
        bytes32 initialKeyHash,
        bytes32 initialGuardianHash,
        uint256 initialGuardianSafePeriod,
        bytes32 newGuardianHash,
        bytes calldata rawOwners,
        bytes calldata keySignature
    ) external;

    /*
     * @dev cancel change guardian
     */
    function cancelSetGuardian(bytes32 slot, bytes calldata rawOwners, bytes calldata keySignature) external;

    /*
     * @dev pre change guardian safe period
     */
    function setGuardianSafePeriod(
        bytes32 slot,
        uint256 newGuardianSafePeriod,
        bytes calldata rawOwners,
        bytes calldata keySignature
    ) external;

    /*
     * @dev pre change guardian safe period
     */
    function setGuardianSafePeriod(
        bytes32 initialKeyHash,
        bytes32 initialGuardianHash,
        uint256 initialGuardianSafePeriod,
        uint256 newGuardianSafePeriod,
        bytes calldata rawOwners,
        bytes calldata keySignature
    ) external;

    /*
     * @dev cancel change guardian safe period
     */
    function cancelSetGuardianSafePeriod(bytes32 slot, bytes calldata rawOwners, bytes calldata keySignature)
        external;
}
