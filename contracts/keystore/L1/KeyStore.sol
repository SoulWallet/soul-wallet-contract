// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./BaseKeyStore.sol";
import "../interfaces/IKeystoreProof.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";

contract KeyStore is BaseKeyStore, IKeystoreProof, EIP712 {
    using ECDSA for bytes32;

    event ApproveHash(address indexed guardian, bytes32 hash);
    event RejectHash(address indexed guardian, bytes32 hash);

    mapping(bytes32 => uint256) approvedHashes;

    bytes32 private constant _TYPE_HASH_SET_KEY = keccak256("SetKey(bytes32 keyStoreSlot,uint256 nonce,bytes32 newKey)");
    bytes32 private constant _TYPE_HASH_SET_GUARDIAN =
        keccak256("SetGuardian(bytes32 keyStoreSlot,uint256 nonce,bytes32 newGuardianHash)");
    bytes32 private constant _TYPE_HASH_SET_GUARDIAN_SAFE_PERIOD =
        keccak256("SetGuardianSafePeriod(bytes32 keyStoreSlot,uint256 nonce,uint64 newGuardianSafePeriod)");
    bytes32 private constant _TYPE_HASH_CANCEL_SET_GUARDIAN =
        keccak256("CancelSetGuardian(bytes32 keyStoreSlot,uint256 nonce)");
    bytes32 private constant _TYPE_HASH_CANCEL_SET_GUARDIAN_SAFE_PERIOD =
        keccak256("CancelSetGuardianSafePeriod(bytes32 keyStoreSlot,uint256 nonce)");
    bytes32 private constant _TYPE_HASH_SOCIAL_RECOVERY =
        keccak256("SocialRecovery(bytes32 keyStoreSlot,uint256 nonce,bytes32 newKey)");

    constructor() EIP712("KeyStore", "1") {}

    function _keyGuard(bytes32 key) internal view override {
        super._keyGuard(key);
        assembly {
            /* not memory-safe */
            // if ((key >> 160) > 0) { revert Errors.INVALID_KEY(); }
            if gt(shr(160, key), 0) {
                // 0xce7045bd == Errors.INVALID_KEY.selector
                mstore(0, 0xce7045bd)
                revert(0, 4)
            }
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
        bytes calldata keySignature
    ) internal view override {
        address signer;
        assembly ("memory-safe") {
            signer := signKey
        }

        bytes32 digest;

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
        } else {
            revert Errors.INVALID_DATA();
        }

        address recoveredAddress = ECDSA.recover(digest, keySignature);
        if (signer != recoveredAddress) {
            revert Errors.INVALID_SIGNATURE();
        }
    }

    /**
     * @dev Why do we need this function:
     * We expect the key to be an Externally Owned Account (EOA),
     * but it is impossible to prevent users from accidentally setting a counterfactual contract address as the key.
     * Adding this function does not introduce any additional costs (except for a limited `switch` with `bytes4`),
     * and it allows for key reset in cases where an incorrect address is set as the key without
     * relying solely on social recovery mechanisms.
     */
    function setKey(bytes32 slot, bytes32 newKey) external onlyInitialized(slot) {
        _keyGuard(newKey);
        bytes32 signKey = _getKey(slot);
        address key;
        assembly ("memory-safe") {
            key := signKey
        }
        if (msg.sender != key) {
            revert Errors.UNAUTHORIZED();
        }
        _saveKey(slot, newKey);
    }

    function keystoreBySlot(bytes32 l1Slot) external view override returns (address signingKey) {
        bytes32 key = _getKey(l1Slot);
        assembly ("memory-safe") {
            signingKey := key
        }
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

        (address[] memory guardians, uint256 threshold, uint256 salt) =
            abi.decode(rawGuardian, (address[], uint256, uint256));
        (salt);
        uint256 guardiansLen = guardians.length;
        // for extreme cases
        if (threshold > guardiansLen) threshold = guardiansLen;

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

                    cursorEnd := add(5, sigLen) // see Note line 219
                    cursor := add(cursor, cursorEnd)
                }

                bytes calldata dynamicData = signatures[5:cursorEnd];
                {
                    (bool success, bytes memory result) = guardians[i].staticcall(
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
                bytes32 key = _approveKey(guardians[i], digest);
                require(approvedHashes[key] == 1, "hash not approved");
                unchecked {
                    cursor += 1; // see Note line 219
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

                    i := add(i, skipTimes) // see Note line 219
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

                    cursor := add(cursor, 65) // see Note line 219
                }
                require(guardians[i] == ECDSA.recover(digest, v, r, s), "guardian signature invalid");
            }
            unchecked {
                i++; // see Note line 219
            }
        }
        if (guardiansLen - skipCount < threshold) {
            revert Errors.GUARDIAN_SIGNATURE_INVALID();
        }
    }
}
