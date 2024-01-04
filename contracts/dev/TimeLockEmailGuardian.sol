// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract TimeLockEmailGuardian is Ownable, AccessControl {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    bytes32 public constant APPROVER_ROLE = keccak256("APPROVER_ROLE");
    mapping(bytes32 => uint256) private approveTime;
    uint256 constant VALID_PERIOD_START = 2 days;
    uint256 constant VALID_PERIOD_END = 7 days;
    bytes4 internal constant MAGICVALUE = 0x1626ba7e;
    bytes4 internal constant INVALID_ID = 0xffffffff;
    bytes32 private constant TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant _TYPE_HASH_SOCIAL_RECOVERY =
        keccak256("SocialRecovery(bytes32 keyStoreSlot,uint256 nonce,bytes32 newSigner)");
    bytes32 private constant _TYPE_HASH_CANCEL_SOCIAL_RECOVERY =
        keccak256("CancelSocialRecovery(bytes32 keyStoreSlot,uint256 nonce,bytes32 newSigner)");
    bytes32 private immutable hashedName;
    bytes32 private immutable hashedVersion;
    address private immutable keystoreAddr;

    event RecoveryApproved(bytes32 indexed slot, uint256 slotNonce, bytes32 newKey, uint256 timestamp);
    event RecoveryCancelled(bytes32 indexed slot, uint256 slotNonce, bytes32 newKey, uint256 timestamp);

    constructor(address _keystoreAddr, address _owner) Ownable(_owner) {
        hashedName = keccak256(bytes("KeyStore"));
        hashedVersion = keccak256(bytes("1"));
        keystoreAddr = _keystoreAddr;
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
    }

    function _domainSeparatorV4() internal view returns (bytes32) {
        return _buildDomainSeparator();
    }

    function _buildDomainSeparator() private view returns (bytes32) {
        return keccak256(abi.encode(TYPE_HASH, hashedName, hashedVersion, block.chainid, address(keystoreAddr)));
    }

    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
        return MessageHashUtils.toTypedDataHash(_domainSeparatorV4(), structHash);
    }

    function approveRecovery(bytes32 slot, uint256 slotNonce, bytes32 newKey, bytes calldata signatureData) public {
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(_TYPE_HASH_SOCIAL_RECOVERY, slot, slotNonce, newKey)));
        require(approveTime[digest] == 0, "already approved");
        (uint256 validUntil, bytes memory signatures) = abi.decode(signatureData, (uint256, bytes));
        require(signatures.length == 65, "invalid signature length");
        require(block.timestamp <= validUntil, "signature expired");
        bytes32 verifyHash = keccak256(abi.encode(digest, validUntil));
        address recoveredAddress = verifyHash.recover(signatures);
        require(hasRole(APPROVER_ROLE, recoveredAddress), "invalid signature");
        approveTime[digest] = block.timestamp;
        emit RecoveryApproved(slot, slotNonce, newKey, block.timestamp);
    }

    function cancleRecovery(bytes32 slot, uint256 slotNonce, bytes32 newKey, bytes calldata signatureData) public {
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(_TYPE_HASH_SOCIAL_RECOVERY, slot, slotNonce, newKey)));
        require(approveTime[digest] != 0, "not approved");
        bytes32 cancelDigest =
            _hashTypedDataV4(keccak256(abi.encode(_TYPE_HASH_CANCEL_SOCIAL_RECOVERY, slot, slotNonce, newKey)));
        (uint256 validUntil, bytes memory signatures) = abi.decode(signatureData, (uint256, bytes));
        require(signatures.length == 65, "invalid signature length");
        require(block.timestamp <= validUntil, "signature expired");
        bytes32 verifyHash = keccak256(abi.encode(cancelDigest, validUntil));
        address recoveredAddress = verifyHash.recover(signatures);
        require(hasRole(APPROVER_ROLE, recoveredAddress), "invalid signature");
        approveTime[digest] = 0;
        emit RecoveryCancelled(slot, slotNonce, newKey, block.timestamp);
    }

    function isValidSignature(bytes32 _hash, bytes memory _signature) public view returns (bytes4) {
        require(_signature.length == 0, "invalid signature length");
        uint256 storedTime = approveTime[_hash];
        if (storedTime == 0) {
            return INVALID_ID;
        }
        uint256 currentTime = block.timestamp;
        if (currentTime >= storedTime + VALID_PERIOD_START && currentTime <= storedTime + VALID_PERIOD_END) {
            return MAGICVALUE;
        }
        return INVALID_ID;
    }
}
