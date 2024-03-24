// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "../interfaces/ISocialRecovery.sol";
import "../../../interfaces/ISoulWallet.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

abstract contract BaseSocialRecovery is ISocialRecovery, EIP712 {
    using ECDSA for bytes32;

    event GuardianSet(address wallet, bytes32 newGuardianHash);
    event DelayPeriodSet(address wallet, uint256 newDelay);
    event RecoveryCancelled(address wallet, bytes32 recoveryId);
    event RecoveryScheduled(address wallet, bytes32 recoveryId, uint256 getTimestamp);
    event RecoveryExecuted(address wallet, bytes32 recoveryId);
    event ApproveHash(address indexed guardian, bytes32 hash);
    event RejectHash(address indexed guardian, bytes32 hash);

    error UN_EXPECTED_OPERATION_STATE(address wallet, bytes32 recoveryId, bytes32 expectedStates);
    error HASH_ALREADY_APPROVED();
    error GUARDIAN_SIGNATURE_INVALID();
    error HASH_ALREADY_REJECTED();

    mapping(address => SocialRecoveryInfo) socialRecoveryInfo;
    mapping(bytes32 => uint256) approvedHashes;
    uint256 internal constant _DONE_TIMESTAMP = uint256(1);

    bytes32 private constant _TYPE_HASH_SOCIAL_RECOVERY =
        keccak256("SocialRecovery(address wallet,uint256 nonce, bytes32[] newOwner)");

    function walletNonce(address wallet) public view override returns (uint256 _nonce) {
        return socialRecoveryInfo[wallet].nonce;
    }

    function getOperationState(address wallet, bytes32 id) public view returns (OperationState) {
        uint256 timestamp = getTimestamp(wallet, id);
        if (timestamp == 0) {
            return OperationState.Unset;
        } else if (timestamp == _DONE_TIMESTAMP) {
            return OperationState.Done;
        } else if (timestamp > block.timestamp) {
            return OperationState.Waiting;
        } else {
            return OperationState.Ready;
        }
    }

    function isOperationPending(address wallet, bytes32 id) public view returns (bool) {
        OperationState state = getOperationState(wallet, id);
        return state == OperationState.Waiting || state == OperationState.Ready;
    }

    function isOperationReady(address wallet, bytes32 id) public view returns (bool) {
        return getOperationState(wallet, id) == OperationState.Ready;
    }

    function isOperation(address wallet, bytes32 id) public view returns (bool) {
        return getOperationState(wallet, id) != OperationState.Unset;
    }

    function getTimestamp(address wallet, bytes32 id) public view returns (uint256) {
        return socialRecoveryInfo[wallet].txCreatedAt[id];
    }

    function setGuardian(bytes32 newGuardianHash) external {
        address wallet = _msgSender();
        socialRecoveryInfo[wallet].guardianHash = newGuardianHash;
        emit GuardianSet(wallet, newGuardianHash);
    }

    function setDelayPeriod(uint256 newDelay) external {
        address wallet = _msgSender();
        socialRecoveryInfo[wallet].delayPeriod = newDelay;
        emit DelayPeriodSet(wallet, newDelay);
    }

    function cancelReocvery(bytes32 recoveryId) external {
        address wallet = _msgSender();
        if (!isOperationPending(wallet, recoveryId)) {
            revert UN_EXPECTED_OPERATION_STATE(
                wallet,
                recoveryId,
                _encodeStateBitmap(OperationState.Waiting) | _encodeStateBitmap(OperationState.Ready)
            );
        }

        delete socialRecoveryInfo[wallet].txCreatedAt[recoveryId];
        _increaseNonce(wallet);
        emit RecoveryCancelled(wallet, recoveryId);
    }
    /**
     * @dev Considering that not all contract are EIP-1271 compatible
     */

    function approveHash(bytes32 hash) external {
        bytes32 key = _approveKey(msg.sender, hash);
        if (approvedHashes[key] == 1) {
            revert HASH_ALREADY_APPROVED();
        }
        approvedHashes[key] = 1;
        emit ApproveHash(msg.sender, hash);
    }

    function rejectHash(bytes32 hash) external {
        bytes32 key = _approveKey(msg.sender, hash);
        if (approvedHashes[key] == 0) {
            revert HASH_ALREADY_REJECTED();
        }
        approvedHashes[key] = 0;
        emit RejectHash(msg.sender, hash);
    }

    function scheduleReocvery(
        address wallet,
        bytes calldata newRawOwners,
        bytes calldata rawGuardian,
        bytes calldata guardianSignature
    ) external override returns (bytes32 recoveryId) {
        recoveryId = hashOperation(wallet, abi.encode(newRawOwners, rawGuardian, guardianSignature));
        if (isOperation(wallet, recoveryId)) {
            revert UN_EXPECTED_OPERATION_STATE(wallet, recoveryId, _encodeStateBitmap(OperationState.Unset));
        }
        bytes32 guardianHash = _getGuardianHash(rawGuardian);
        _checkGuardianHash(wallet, guardianHash);
        _verifyGuardianSignature(wallet, walletNonce(wallet), newRawOwners, rawGuardian, guardianSignature);
        uint256 scheduleTime = _setTimeStamp(wallet, recoveryId);
        emit RecoveryScheduled(wallet, recoveryId, scheduleTime);
    }

    function executeReocvery(
        address wallet,
        bytes calldata newRawOwners,
        bytes calldata rawGuardian,
        bytes calldata guardianSignature
    ) external override {
        bytes32 recoveryId = hashOperation(wallet, abi.encode(newRawOwners, rawGuardian, guardianSignature));
        if (!isOperationReady(wallet, recoveryId)) {
            revert UN_EXPECTED_OPERATION_STATE(wallet, recoveryId, _encodeStateBitmap(OperationState.Ready));
        }
        _recoveryOwner(wallet, newRawOwners);

        if (!isOperationReady(wallet, recoveryId)) {
            revert UN_EXPECTED_OPERATION_STATE(wallet, recoveryId, _encodeStateBitmap(OperationState.Ready));
        }
        socialRecoveryInfo[wallet].txCreatedAt[recoveryId] = _DONE_TIMESTAMP;
        _increaseNonce(wallet);
        emit RecoveryExecuted(wallet, recoveryId);
    }

    function _recoveryOwner(address wallet, bytes calldata newRawOwners) internal {
        bytes32[] memory owners = abi.decode(newRawOwners, (bytes32[]));
        ISoulWallet soulwallet = ISoulWallet(payable(wallet));
        soulwallet.resetOwners(owners);
    }

    function _verifyGuardianSignature(
        address wallet,
        uint256 nonce,
        bytes calldata newRawOwners,
        bytes calldata rawGuardian,
        bytes calldata guardianSignature
    ) internal view {
        address[] memory newOwners = abi.decode(newRawOwners, (address[]));
        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(_TYPE_HASH_SOCIAL_RECOVERY, wallet, nonce, keccak256(abi.encodePacked(newOwners))))
        );
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
            revert GUARDIAN_SIGNATURE_INVALID();
        }
    }

    function _approveKey(address sender, bytes32 hash) private pure returns (bytes32 key) {
        key = keccak256(abi.encode(sender, hash));
    }

    function _checkGuardianHash(address wallet, bytes32 guardianHash) internal view {
        if (socialRecoveryInfo[wallet].guardianHash != guardianHash) {
            revert("Invalid guardian hash");
        }
    }

    function _clearWalletSocialRecoveryInfo(address wallet) internal {
        delete socialRecoveryInfo[wallet];
    }

    function _getGuardianHash(bytes calldata rawGuardian) internal pure returns (bytes32 guardianHash) {
        return keccak256(rawGuardian);
    }

    function _setTimeStamp(address wallet, bytes32 id) internal returns (uint256) {
        uint256 scheduleTime = block.timestamp + socialRecoveryInfo[wallet].delayPeriod;
        socialRecoveryInfo[wallet].txCreatedAt[id] = scheduleTime;
        return scheduleTime;
    }

    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }

    function _increaseNonce(address wallet) internal {
        uint256 _newNonce = walletNonce(wallet) + 1;
        socialRecoveryInfo[wallet].nonce = _newNonce;
    }

    function _setGuardianHash(address wallet, bytes32 guardianHash) internal {
        socialRecoveryInfo[wallet].guardianHash = guardianHash;
    }

    function _setDelayPeriod(address wallet, uint256 delayPeriod) internal {
        socialRecoveryInfo[wallet].delayPeriod = delayPeriod;
    }

    function hashOperation(address wallet, bytes memory data) internal pure virtual returns (bytes32) {
        return keccak256(abi.encode(wallet, data));
    }

    function _encodeStateBitmap(OperationState operationState) internal pure returns (bytes32) {
        return bytes32(1 << uint8(operationState));
    }

    function _parseGuardianData(bytes calldata rawGuardian) internal pure returns (GuardianData memory) {
        (address[] memory guardians, uint256 threshold, uint256 salt) =
            abi.decode(rawGuardian, (address[], uint256, uint256));
        return GuardianData({guardians: guardians, threshold: threshold, salt: salt});
    }
}
