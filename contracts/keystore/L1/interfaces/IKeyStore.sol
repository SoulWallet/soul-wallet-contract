// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

interface IKeyStore {
    /* 
    #######################################################################################################################################
    #                                                                                                                                     #
    #     Why do we need `uint64 initialGuardianSafePeriod`?                                                                              #
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
    event Initialized(bytes32 indexed slot);

    /**
     * @dev Emitted when `key` is changed in `slot`.
     */
    event KeyChanged(bytes32 indexed slot, bytes32 key);

    /**
     * @dev Emitted when PreSetGuardian is called.
     */
    event SetGuardian(bytes32 indexed slot, bytes32 guardianHash, uint64 effectAt);

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
    event SetGuardianSafePeriod(bytes32 indexed slot, uint64 guardianSafePeriod, uint64 effectAt);

    /**
     * @dev Emitted when `guardianSafePeriod` is changed in `slot`.
     */
    event GuardianSafePeriodChanged(bytes32 indexed slot, uint64 guardianSafePeriod);

    /**
     * @dev Emitted when CancelSetGuardianSafePeriod is called.
     */
    event CancelSetGuardianSafePeriod(bytes32 indexed slot, uint64 guardianSafePeriod);

    /*
        # Storage Layout

        slot offset
        ┌──────────┬────────────────────────────────┬────────────────┐
        │  offset 0│ Key (EOA)                      │                │
        ├──────────┼────────────────────────────────┤                │
        │  offset 1│ nonce                          │                │
        ├──────────┼────────────────────────────────┤                ├──────────────────┐
        │  offset 2│ guardianHash                   │                │                  │
        ├──────────┼────────────────────────────────┤                │                  │
        │  offset 3│ pendingGuardianHash            │                │                  │
        ├──────────┼────────────────────────────────┤  KeyStoreInfo  │                  │
        │  offset 4│ guardianActivateAt             │                │                  │
        ├──────────┼────────────────────────────────┤                │                  │
        │  offset 4│ guardianSafePeriod             │                │   guardianInfo   │
        ├─────────-┼────────────────────────────────┤                │                  │
        │  offset 4│ pendingGuardianSafePeriod      │                │                  │
        ├──────────┼────────────────────────────────┤                │                  │
        │  offset 4│ guardianSafePeriodActivateAt   │                │                  │
        └──────────┴────────────────────────────────┴────────────────┴──────────────────┘
    
    */

    struct keyStoreInfo {
        /*
         * @dev why use bytes32 instead of address?
         * 1. if use EOA as a key, address is padded to 32 bytes anyway when used in the contract, so there is no performance difference
         * 2. if use merkle tree root as a key root, bytes32 is required
         */
        bytes32 key;
        // prevent replay attack
        uint256 nonce;
        // guardian now
        bytes32 guardianHash;
        // guardian next
        bytes32 pendingGuardianHash;
        // `guardian next` effective time
        uint64 guardianActivateAt;
        // guardian safe period (in seconds)    48 hours <= guardianSafePeriod <= 30 days
        uint64 guardianSafePeriod;
        // guardian safe period next
        uint64 pendingGuardianSafePeriod;
        // `guardian safe period next` effective time
        uint64 guardianSafePeriodActivateAt;
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
        uint64 guardianActivateAt;
        // guardian safe period (in seconds)    48 hours <= guardianSafePeriod <= 30 days
        uint64 guardianSafePeriod;
        // guardian safe period next
        uint64 pendingGuardianSafePeriod;
        // `guardian safe period next` effective time
        uint64 guardianSafePeriodActivateAt;
    }

    /**
     * @dev get keystore nonce
     */
    function nonce(bytes32 slot) external view returns (uint256 _nonce);

    /**
     * @dev calculate slot
     */
    function getSlot(bytes32 initialKey, bytes32 initialGuardianHash, uint64 initialGuardianSafePeriod)
        external
        pure
        returns (bytes32 slot);

    /**
     * @dev calculate guardian hash
     */
    function getGuardianHash(bytes calldata rawGuardian) external pure returns (bytes32 guardianHash);

    /**
     * @dev get key is saved in slot
     */
    function getKey(bytes32 slot) external view returns (bytes32 key);

    /**
     * @dev change key
     * @param keySignature `signature of old key`
     */
    function setKey(bytes32 slot, bytes32 newKey, bytes calldata keySignature) external;

    /**
     * @dev change key
     * @param keySignature `signature of old key`
     */
    function setKey(
        bytes32 initialKey,
        bytes32 initialGuardianHash,
        uint64 initialGuardianSafePeriod,
        bytes32 newKey,
        bytes calldata keySignature
    ) external;

    /**
     * @dev social recovery
     * @param guardianSignature `signature of guardian`
     */
    function setKey(
        bytes32 initialKey,
        bytes32 initialGuardianHash,
        uint64 initialGuardianSafePeriod,
        bytes32 newKey,
        bytes calldata rawGuardian,
        bytes calldata guardianSignature
    ) external;

    /**
     * @dev social recovery
     * @param guardianSignature `signature of guardian`
     */
    function setKey(bytes32 slot, bytes32 newKey, bytes calldata rawGuardian, bytes calldata guardianSignature)
        external;

    /**
     * @dev get keystore data
     */
    function getKeyStoreInfo(bytes32 slot) external view returns (keyStoreInfo memory _keyStoreInfo);

    /*
     * @dev pre change guardian
     */
    function setGuardian(bytes32 slot, bytes32 newGuardianHash, bytes calldata keySignature) external;

    /*
     * @dev pre change guardian
     */
    function setGuardian(
        bytes32 initialKey,
        bytes32 initialGuardianHash,
        uint64 initialGuardianSafePeriod,
        bytes32 newGuardianHash,
        bytes calldata keySignature
    ) external;

    /*
     * @dev cancel change guardian
     */
    function cancelSetGuardian(bytes32 slot, bytes calldata keySignature) external;

    /*
     * @dev pre change guardian safe period
     */
    function setGuardianSafePeriod(bytes32 slot, uint64 newGuardianSafePeriod, bytes calldata keySignature) external;

    /*
     * @dev pre change guardian safe period
     */
    function setGuardianSafePeriod(
        bytes32 initialKey,
        bytes32 initialGuardianHash,
        uint64 initialGuardianSafePeriod,
        uint64 newGuardianSafePeriod,
        bytes calldata keySignature
    ) external;

    /*
     * @dev cancel change guardian safe period
     */
    function cancelSetGuardianSafePeriod(bytes32 slot, bytes calldata keySignature) external;
}
