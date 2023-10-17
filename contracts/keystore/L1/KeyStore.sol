// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "./BaseKeyStore.sol";
import "../interfaces/IKeyStoreProof.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "../../base/ValidatorManager.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract KeyStore is IKeyStoreProof, EIP712, BaseKeyStore, ValidatorManager, Ownable {
    using ECDSA for bytes32;

    IKeyStoreStorage private immutable _KEYSTORE_STORAGE;

    event ApproveHash(address indexed guardian, bytes32 hash);
    event RejectHash(address indexed guardian, bytes32 hash);
    event KeyStoreUpgraded(bytes32 indexed slot, address indexed newLogic);

    mapping(bytes32 => uint256) approvedHashes;
    mapping(address => bool) trustedKeystoreLogic;

    bytes32 private constant _TYPE_HASH_SET_KEY =
        keccak256("SetKey(bytes32 keyStoreSlot,uint256 nonce,bytes32 newSigner)");
    bytes32 private constant _TYPE_HASH_SET_GUARDIAN =
        keccak256("SetGuardian(bytes32 keyStoreSlot,uint256 nonce,bytes32 newGuardianHash)");
    bytes32 private constant _TYPE_HASH_SET_GUARDIAN_SAFE_PERIOD =
        keccak256("SetGuardianSafePeriod(bytes32 keyStoreSlot,uint256 nonce,uint64 newGuardianSafePeriod)");
    bytes32 private constant _TYPE_HASH_CANCEL_SET_GUARDIAN =
        keccak256("CancelSetGuardian(bytes32 keyStoreSlot,uint256 nonce)");
    bytes32 private constant _TYPE_HASH_CANCEL_SET_GUARDIAN_SAFE_PERIOD =
        keccak256("CancelSetGuardianSafePeriod(bytes32 keyStoreSlot,uint256 nonce)");
    bytes32 private constant _TYPE_HASH_SOCIAL_RECOVERY =
        keccak256("SocialRecovery(bytes32 keyStoreSlot,uint256 nonce,bytes32 newSigner)");
    bytes32 private constant _TYPE_HASH_UPGRADE_KEYSTORE_LOGIC =
        keccak256("KeyStoreUpgrade(bytes32 keyStoreSlot,uint256 nonce,address newLogic)");

    constructor(IValidator _validator, IKeyStoreStorage _keystorStorage, address _owner)
        EIP712("KeyStore", "1")
        ValidatorManager(_validator)
        Ownable(_owner)
    {
        _KEYSTORE_STORAGE = _keystorStorage;
    }

    function _keyGuard(bytes32 key) internal view override {
        super._keyGuard(key);
    }

    function _verifyStructHash(bytes32 slot, uint256 slotNonce, Action action, bytes32 data)
        private
        view
        returns (bytes32 digest)
    {
        if (action == Action.SET_KEY) {
            // SetKey(bytes32 slot,uint256 nonce,bytes32 newKey)
            digest = _hashTypedDataV4(keccak256(abi.encode(_TYPE_HASH_SET_KEY, slot, slotNonce, data)));
        } else if (action == Action.SET_GUARDIAN) {
            // SetGuardian(bytes32 slot,uint256 nonce,bytes32 newGuardianHash)
            digest = _hashTypedDataV4(keccak256(abi.encode(_TYPE_HASH_SET_GUARDIAN, slot, slotNonce, data)));
        } else if (action == Action.SET_GUARDIAN_SAFE_PERIOD) {
            // SetGuardianSafePeriod(bytes32 slot,uint256 nonce,uint64 newGuardianSafePeriod)
            // bytes32 -> uint64
            uint64 newGuardianSafePeriod;
            assembly ("memory-safe") {
                newGuardianSafePeriod := data
            }
            digest = _hashTypedDataV4(
                keccak256(abi.encode(_TYPE_HASH_SET_GUARDIAN_SAFE_PERIOD, slot, slotNonce, newGuardianSafePeriod))
            );
        } else if (action == Action.CANCEL_SET_GUARDIAN) {
            // CancelSetGuardian(bytes32 slot,uint256 nonce)
            digest = _hashTypedDataV4(keccak256(abi.encode(_TYPE_HASH_CANCEL_SET_GUARDIAN, slot, slotNonce)));
        } else if (action == Action.CANCEL_SET_GUARDIAN_SAFE_PERIOD) {
            // CancelSetGuardianSafePeriod(bytes32 slot,uint256 nonce)
            digest =
                _hashTypedDataV4(keccak256(abi.encode(_TYPE_HASH_CANCEL_SET_GUARDIAN_SAFE_PERIOD, slot, slotNonce)));
        } else if (action == Action.UPGRADE_KEYSTORE_LOGIC) {
            // KeyStoreUpgrade(bytes32 keyStoreSlot,uint256 nonce,address newLogic)
            address newKeystoreLogic;
            assembly ("memory-safe") {
                newKeystoreLogic := data
            }
            digest = _hashTypedDataV4(
                keccak256(abi.encode(_TYPE_HASH_UPGRADE_KEYSTORE_LOGIC, slot, slotNonce, newKeystoreLogic))
            );
        } else {
            revert Errors.INVALID_DATA();
        }
    }

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
        bytes memory rawOwners,
        bytes memory keySignature
    ) internal view override {
        bytes32[] memory owners = abi.decode(rawOwners, (bytes32[]));
        require(signKey == _getOwnersHash(rawOwners), "invaid rawOwners data");

        bytes32 digest = _verifyStructHash(slot, slotNonce, action, data);

        (, bytes32 recovered, bool success) = validator().recoverSignature(digest, keySignature);
        if (!success) {
            revert Errors.INVALID_SIGNATURE();
        }

        bool result = false;
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == recovered) {
                result = true;
                break;
            }
        }
        if (!result) {
            revert Errors.INVALID_SIGNATURE();
        }
    }

    function keystoreBySlot(bytes32 l1Slot) external view override returns (bytes32 signingKeyHash) {
        return _getKey(l1Slot);
    }

    function rawOwnersBySlot(bytes32 l1Slot) external view override returns (bytes memory owners) {
        return _getRawOwners(l1Slot);
    }

    function _approveKey(address sender, bytes32 hash) private pure returns (bytes32 key) {
        key = keccak256(abi.encode(sender, hash));
    }

    /**
     * @dev Considering that not all contract are EIP-1271 compatible
     */
    function approveHash(bytes32 hash) external {
        bytes32 key = _approveKey(msg.sender, hash);
        if (approvedHashes[key] == 1) {
            revert Errors.HASH_ALREADY_APPROVED();
        }
        approvedHashes[key] = 1;
        emit ApproveHash(msg.sender, hash);
    }

    function rejectHash(bytes32 hash) external {
        bytes32 key = _approveKey(msg.sender, hash);
        if (approvedHashes[key] == 0) {
            revert Errors.HASH_ALREADY_REJECTED();
        }
        approvedHashes[key] = 0;
        emit RejectHash(msg.sender, hash);
    }

    struct GuardianData {
        address[] guardians;
        uint256 threshold;
        uint256 salt;
    }

    function _parseGuardianData(bytes calldata rawGuardian) internal pure returns (GuardianData memory) {
        (address[] memory guardians, uint256 threshold, uint256 salt) =
            abi.decode(rawGuardian, (address[], uint256, uint256));
        return GuardianData({guardians: guardians, threshold: threshold, salt: salt});
    }

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
    ) internal view override {
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(_TYPE_HASH_SOCIAL_RECOVERY, slot, slotNonce, newKey)));
        GuardianData memory guardianData = _parseGuardianData(rawGuardian);
        uint256 guardiansLen = guardianData.guardians.length;
        // for extreme cases
        if (guardianData.threshold > guardiansLen) guardianData.threshold = guardiansLen;

        /* 
            keySignature structure:
            ┌──────────────┬──────────────┬──────────────┬──────────────┐
            │              │              │              │              │
            │   signature1 │   signature2 │      ...     │   signatureN │
            │              │              │              │              │
            └──────────────┴──────────────┴──────────────┴──────────────┘

            one signature structure:
            ┌──────────┬──────────────┬──────────┬────────────────┐
            │          │              │          │                │
            │    v     │       s      │   r      │  dynamic data  │
            │  bytes1  │bytes4|bytes32│  bytes32 │     dynamic    │
            │  (must)  │  (optional)  │(optional)│   (optional)   │
            └──────────┴──────────────┴──────────┴────────────────┘

            data logic description:
                v = 0
                    EIP-1271 signature
                    s: bytes4 Length of signature data 
                    r: no set
                    dynamic data: signature data

                v = 1
                    approved hash
                    r: no set
                    s: no set
                
                v = 2
                    skip
                    s: bytes4 skip times
                    r: no set

                v > 2
                    EOA signature
                    r: bytes32
                    s: bytes32

            ==============================================================
            Note: Why is the definition of 's' unstable (bytes4|bytes32)?
                  If 's' is defined as bytes32, it incurs lower read costs( shr(224, calldataload() -> calldataload() ). However, to prevent arithmetic overflow, all calculations involving 's' need to be protected against overflow, which leads to higher overhead.
                  If, in certain cases, 's' is defined as bytes4 (up to 4GB), there is no need to perform overflow prevention under the current known block gas limit.
                  Overall, it is more suitable for both Layer1 and Layer2. 
         */
        {
            uint8 v;
            uint256 cursor = 0;

            uint256 skipCount = 0;
            uint256 guardianSignatureLen = guardianSignature.length;
            for (uint256 i = 0; i < guardiansLen;) {
                if (cursor >= guardianSignatureLen) break;
                bytes calldata signatures = guardianSignature[cursor:];
                assembly ("memory-safe") {
                    v := byte(0, calldataload(signatures.offset))
                }

                if (v == 0) {
                    /*
                    v = 0
                        EIP-1271 signature
                        s: bytes4 Length of signature data 
                        r: no set
                        dynamic data: signature data
                 */
                    uint256 cursorEnd;
                    assembly ("memory-safe") {
                        // read 's' as bytes4
                        let sigLen := shr(224, calldataload(add(signatures.offset, 1)))

                        cursorEnd := add(5, sigLen) // see Note line 223
                        cursor := add(cursor, cursorEnd)
                    }

                    bytes calldata dynamicData = signatures[5:cursorEnd];
                    {
                        (bool success, bytes memory result) = guardianData.guardians[i].staticcall(
                            abi.encodeWithSelector(IERC1271.isValidSignature.selector, digest, dynamicData)
                        );
                        require(
                            success && result.length == 32
                                && abi.decode(result, (bytes32)) == bytes32(IERC1271.isValidSignature.selector),
                            "contract signature invalid"
                        );
                    }
                } else if (v == 1) {
                    /* 
                    v = 1
                        approved hash
                        r: no set
                        s: no set
                 */
                    bytes32 key = _approveKey(guardianData.guardians[i], digest);
                    require(approvedHashes[key] == 1, "hash not approved");
                    unchecked {
                        cursor += 1; // see Note line 223
                    }
                } else if (v == 2) {
                    /* 
                    v = 2
                        skip
                        s: bytes4 skip times
                        r: no set
                 */
                    assembly ("memory-safe") {
                        // read 's' as bytes4
                        let skipTimes := shr(224, calldataload(add(signatures.offset, 1)))

                        i := add(i, skipTimes) // see Note line 223
                        skipCount := add(skipCount, add(skipTimes, 1))
                        cursor := add(cursor, 5)
                    }
                } else {
                    /* 
                    v > 2
                        EOA signature
                 */
                    bytes32 s;
                    bytes32 r;
                    assembly ("memory-safe") {
                        s := calldataload(add(signatures.offset, 1))
                        r := calldataload(add(signatures.offset, 33))

                        cursor := add(cursor, 65) // see Note line 223
                    }
                    require(guardianData.guardians[i] == ECDSA.recover(digest, v, r, s), "guardian signature invalid");
                }
                unchecked {
                    i++; // see Note line 223
                }
            }
            if (guardiansLen - skipCount < guardianData.threshold) {
                revert Errors.GUARDIAN_SIGNATURE_INVALID();
            }
        }
    }

    function keyStoreStorage() public view virtual override returns (IKeyStoreStorage) {
        return _KEYSTORE_STORAGE;
    }

    function upgradeKeystore(bytes32 slot, address newLogic, bytes calldata keySignature)
        external
        onlyInitialized(slot)
    {
        if (!trustedKeystoreLogic[newLogic]) {
            revert Errors.UNTRUSTED_KEYSTORE_LOGIC();
        }
        bytes32 signKey = _getKey(slot);
        bytes memory rawOwners = _getRawOwners(slot);
        verifySignature(
            slot,
            _getNonce(slot),
            signKey,
            Action.UPGRADE_KEYSTORE_LOGIC,
            bytes32(bytes20(newLogic)),
            rawOwners,
            keySignature
        );
        _increaseNonce(slot);
        _setKeyStoreLogic(slot, newLogic);
        emit KeyStoreUpgraded(slot, newLogic);
    }

    // admin operation
    function enableTrustedKeystoreLogic(address logic) external onlyOwner {
        trustedKeystoreLogic[logic] = true;
    }
}
