// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./ISocialRecoveryModule.sol";
import "../BaseModule.sol";
import "../../libraries/AddressLinkedList.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "../../interfaces/ISoulWallet.sol";

contract SocialRecoveryModule is ISocialRecoveryModule, BaseModule {
    using AddressLinkedList for mapping(address => address);

    string public constant NAME = "Soulwallet Social Recovery Module";
    string public constant VERSION = "0.0.1";

    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant _DOMAIN_SEPARATOR_TYPEHASH =
        0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    // keccak256("SocialRecovery(address wallet,address[] newOwners,uint256 nonce)");
    bytes32 private constant _SOCIAL_RECOVERY_TYPEHASH =
        0x333ef7ecc7b8a82065578df0879cefc36c32344d49afdf1e0370a60babe64feb;

    bytes4 private constant _FUNC_RESET_OWNER = bytes4(keccak256("resetOwner(address)"));
    bytes4 private constant _FUNC_RESET_OWNERS = bytes4(keccak256("resetOwners(address[])"));

    mapping(address => uint256) walletRecoveryNonce;
    mapping(address => uint256) walletInitSeed;

    mapping(address => GuardianInfo) internal walletGuardian;
    mapping(address => PendingGuardianEntry) internal walletPendingGuardian;

    mapping(address => mapping(bytes32 => uint256)) approvedRecords;
    mapping(address => RecoveryEntry) recoveryEntries;

    uint128 private __seed = 0;

    modifier authorized(address _wallet) {
        require(ISoulWallet(_wallet).isAuthorizedModule(address(this)), "unauthorized");
        _;
    }

    modifier whenRecovery(address _wallet) {
        require(recoveryEntries[_wallet].executeAfter > 0, "no ongoing recovery");
        _;
    }

    modifier whenNotRecovery(address _wallet) {
        require(recoveryEntries[_wallet].executeAfter == 0, "ongoing recovery");
        _;
    }

    function getChainId() public view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    function domainSeparator() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                _DOMAIN_SEPARATOR_TYPEHASH,
                keccak256(abi.encodePacked(NAME)),
                keccak256(abi.encodePacked(VERSION)),
                getChainId(),
                this
            )
        );
    }

    function encodeSocialRecoveryData(address _wallet, address[] calldata _newOwners, uint256 _nonce)
        public
        view
        returns (bytes memory)
    {
        bytes32 recoveryHash =
            keccak256(abi.encode(_SOCIAL_RECOVERY_TYPEHASH, _wallet, keccak256(abi.encodePacked(_newOwners)), _nonce));
        return abi.encodePacked(bytes1(0x19), bytes1(0x01), domainSeparator(), recoveryHash);
    }

    function getSocialRecoveryHash(address _wallet, address[] calldata _newOwners, uint256 _nonce)
        public
        view
        returns (bytes32)
    {
        return keccak256(encodeSocialRecoveryData(_wallet, _newOwners, _nonce));
    }

    function _newSeed() private returns (uint128) {
        __seed++;
        return __seed;
    }

    function inited(address wallet) internal view override returns (bool) {
        return walletInitSeed[wallet] != 0;
    }

    function _init(bytes calldata data) internal override {
        (address[] memory _guardians, uint256 _threshold, bytes32 _guardianHash) =
            abi.decode(data, (address[], uint256, bytes32));
        address _sender = sender();
        require(_threshold > 0 && _threshold <= _guardians.length, "threshold error");
        if (_guardians.length > 0) {
            require(_guardianHash == bytes32(0), "cannot set anonomous guardian with onchain guardian");
        }
        if (_guardians.length == 0) {
            require(_guardianHash != bytes32(0), "guardian config error");
        }
        for (uint256 i = 0; i < _guardians.length; i++) {
            walletGuardian[_sender].guardians.add(_guardians[i]);
        }
        walletGuardian[_sender].guardianHash = _guardianHash;
        walletGuardian[_sender].threshold = _threshold;
        walletInitSeed[_sender] = _newSeed();
    }

    function _deInit() internal override {
        address _sender = sender();
        walletInitSeed[_sender] = 0;
        delete walletGuardian[_sender];
        delete walletPendingGuardian[_sender];
        delete recoveryEntries[_sender];
    }

    function _checkLatestGuardian(address wallet) private {
        if (
            walletPendingGuardian[wallet].pendingUntil > 0
                && walletPendingGuardian[wallet].pendingUntil > block.timestamp
        ) {
            if (walletPendingGuardian[wallet].guardianHash != bytes32(0)) {
                // if set anonomous guardian, clear onchain guardian
                walletGuardian[wallet].guardians.clear();
                walletGuardian[wallet].guardianHash = walletPendingGuardian[wallet].guardianHash;
            } else if (walletPendingGuardian[wallet].guardians.length > 0) {
                //if set onchain guardian, clear anonomous guardian
                walletGuardian[wallet].guardianHash = bytes32(0);
                walletGuardian[wallet].guardians.clear();
                for (uint256 i = 0; i < walletPendingGuardian[wallet].guardians.length; i++) {
                    walletGuardian[wallet].guardians.add(walletPendingGuardian[wallet].guardians[i]);
                }
            }

            delete walletPendingGuardian[wallet];
        }
    }

    modifier checkLatestGuardian(address wallet) {
        _checkLatestGuardian(wallet);
        _;
    }

    function guardiansCount(address wallet) public view returns (uint256) {
        return walletGuardian[wallet].guardians.size();
    }

    function getGuardians(address wallet) public view returns (address[] memory) {
        return walletGuardian[wallet].guardians.list(AddressLinkedList.SENTINEL_ADDRESS, type(uint8).max);
    }

    function updateGuardians(address[] calldata _guardians, uint256 _threshold, bytes32 _guardianHash)
        external
        authorized(sender())
        whenNotRecovery(sender())
        checkLatestGuardian(sender())
    {
        address wallet = sender();
        if (_guardians.length > 0) {
            require(_guardianHash == bytes32(0), "cannot set anonomous guardian with onchain guardian");
        }
        if (_guardians.length == 0) {
            require(_guardianHash != bytes32(0), "guardian config error");
        }
        require(_threshold > 0 && _threshold <= _guardians.length, "threshold error");
        PendingGuardianEntry memory pendingEntry;
        pendingEntry.pendingUntil = block.timestamp + 2 days;
        pendingEntry.guardians = _guardians;

        pendingEntry.guardianHash = _guardianHash;
        walletPendingGuardian[wallet] = pendingEntry;
    }

    // owner or guardian
    function cancelSetGuardians(address wallet) external authorized(wallet) checkLatestGuardian(wallet) {
        require(walletPendingGuardian[wallet].pendingUntil > 0, "no pending guardian");
        if (wallet != sender()) {
            if (!isGuardian(wallet, sender())) {
                revert("not authorized");
            }
        }
        delete walletPendingGuardian[wallet];
    }

    function revealAnomousGuardians(address wallet, address[] calldata guardians, uint256 salt)
        public
        authorized(wallet)
        checkLatestGuardian(wallet)
    {
        if (wallet != sender()) {
            if (!isGuardian(wallet, sender())) {
                revert("not authorized");
            }
        }
        address lastGuardian = address(0);
        address currenGuardian;
        for (uint256 i = 0; i < guardians.length; i++) {
            currenGuardian = guardians[i];
            require(currenGuardian > lastGuardian, "guardian list error");
            lastGuardian = currenGuardian;
        }
        // 1. check hash
        bytes32 guardianHash = getAnomousGuardianHash(guardians, salt);
        if (guardianHash != walletGuardian[wallet].guardianHash) {
            revert("guardian hash error");
        }
        // 2. update guardian list in storage
        for (uint256 i = 0; i < guardians.length; i++) {
            walletGuardian[wallet].guardians.add(guardians[i]);
        }
        // 3. clear anonomous guardian hash
        walletGuardian[wallet].guardianHash = bytes32(0);
        emit AnonymousGuardianRevealed(wallet, guardians, guardianHash);
    }

    function getAnomousGuardianHash(address[] calldata guardians, uint256 salt) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(guardians, salt));
    }

    function batchApproveRecovery(
        address _wallet,
        address[] calldata _newOwners,
        uint256 signatureCount,
        bytes memory signatures
    ) external authorized(_wallet) {
        // TODO . clear pending guardian setting
        require(_newOwners.length > 0, "owners cannot be empty");
        uint256 _nonce = nonce(_wallet);
        // get recoverHash = hash(recoveryRecord) with EIP712
        bytes32 recoveryHash = getSocialRecoveryHash(_wallet, _newOwners, _nonce);
        // verify signatures, verify is guardian
        checkNSignatures(_wallet, recoveryHash, signatureCount, signatures);
        // if (numConfirmed == numGuardian) execute Recovery
        if (signatureCount == walletGuardian[_wallet].guardians.size()) {
            // perform recovery
            _performRecovery(_wallet, _newOwners);
        }
        if (signatureCount > threshold(_wallet)) {
            _pendingRecovery(_wallet, _newOwners, _nonce);
        }
    }

    function executeRecovery(address _wallet) external whenRecovery(_wallet) authorized(_wallet) {
        RecoveryEntry memory request = recoveryEntries[_wallet];
        // check RecoveryEntry.executeUntil > block.timestamp
        require(block.timestamp >= request.executeAfter, "recovery period still pending");
        _performRecovery(_wallet, request.newOwners);
    }

    function _performRecovery(address _wallet, address[] memory _newOwners) private {
        // check nonce and update nonce
        require(_newOwners.length > 0, "owners cannot be empty");
        if (recoveryEntries[_wallet].nonce == nonce(_wallet)) {
            walletRecoveryNonce[_wallet]++;
        }
        // delete RecoveryEntry
        delete recoveryEntries[_wallet];

        ISoulWallet soulwallet = ISoulWallet(payable(_wallet));
        // update owners
        soulwallet.resetOwners(_newOwners);
        // emit RecoverySuccess
        emit SocialRecovery(_wallet, _newOwners);
    }

    function cancelRecovery(address _wallet) external authorized(_wallet) whenRecovery(_wallet) {
        require(msg.sender == _wallet, "only wallet owner can cancel recovery");
        emit SocialRecoveryCanceled(_wallet, recoveryEntries[_wallet].nonce);
        delete recoveryEntries[_wallet];
    }

    function _pendingRecovery(address _wallet, address[] calldata _newOwners, uint256 _nonce) private {
        // new pending recovery
        uint256 executeAfter = block.timestamp + 2 days;
        recoveryEntries[_wallet] = RecoveryEntry(_newOwners, executeAfter, _nonce);
        walletRecoveryNonce[_wallet]++;
        emit PendingRecovery(_wallet, _newOwners, _nonce, executeAfter);
    }

    /// @dev divides bytes signature into `uint8 v, bytes32 r, bytes32 s`.
    /// @notice Make sure to perform a bounds check for @param pos, to avoid out of bounds access on @param signatures
    /// @param pos which signature to read. A prior bounds check of this parameter should be performed, to avoid out of bounds access
    /// @param signatures concatenated rsv signatures
    function signatureSplit(bytes memory signatures, uint256 pos)
        internal
        pure
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        // The signature format is a compact form of:
        //   {bytes32 r}{bytes32 s}{uint8 v}
        // Compact means, uint8 is not padded to 32 bytes.
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let signaturePos := mul(0x41, pos)
            r := mload(add(signatures, add(signaturePos, 0x20)))
            s := mload(add(signatures, add(signaturePos, 0x40)))
            // Here we are loading the last 32 bytes, including 31 bytes
            // of 's'. There is no 'mload8' to do this.
            //
            // 'byte' is not working due to the Solidity parser, so lets
            // use the second best option, 'and'
            v := and(mload(add(signatures, add(signaturePos, 0x41))), 0xff)
        }
    }

    /**
     * referece from gnosis safe validation
     *
     */
    function checkNSignatures(address _wallet, bytes32 dataHash, uint256 signatureCount, bytes memory signatures)
        public
        view
    {
        // Check that the provided signature data is not too short
        require(signatures.length >= signatureCount * 65, "signatures too short");
        // There cannot be an owner with address 0.
        address lastOwner = address(0);
        address currentOwner;
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 i;
        for (i = 0; i < signatureCount; i++) {
            (v, r, s) = signatureSplit(signatures, i);
            if (v == 0) {
                // If v is 0 then it is a contract signature
                // When handling contract signatures the address of the contract is encoded into r
                currentOwner = address(uint160(uint256(r)));

                // Check that signature data pointer (s) is not pointing inside the static part of the signatures bytes
                // This check is not completely accurate, since it is possible that more signatures than the threshold are send.
                // Here we only check that the pointer is not pointing inside the part that is being processed
                require(uint256(s) >= signatureCount * 65, "contract signatures too short");

                // Check that signature data pointer (s) is in bounds (points to the length of data -> 32 bytes)
                require(uint256(s) + (32) <= signatures.length, "contract signatures out of bounds");

                // Check if the contract signature is in bounds: start of data is s + 32 and end is start + signature length
                uint256 contractSignatureLen;
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    contractSignatureLen := mload(add(add(signatures, s), 0x20))
                }
                require(uint256(s) + 32 + contractSignatureLen <= signatures.length, "contract signature wrong offset");

                // Check signature
                bytes memory contractSignature;
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    // The signature data for contract signatures is appended to the concatenated signatures and the offset is stored in s
                    contractSignature := add(add(signatures, s), 0x20)
                }
                (bool success, bytes memory result) = currentOwner.staticcall(
                    abi.encodeWithSelector(IERC1271.isValidSignature.selector, dataHash, contractSignature)
                );
                require(
                    success && result.length == 32
                        && abi.decode(result, (bytes32)) == bytes32(IERC1271.isValidSignature.selector),
                    "contract signature invalid"
                );
            } else if (v == 1) {
                // If v is 1 then it is an approved hash
                // When handling approved hashes the address of the approver is encoded into r
                currentOwner = address(uint160(uint256(r)));
                // Hashes are automatically approved by the sender of the message or when they have been pre-approved via a separate transaction
                require(
                    msg.sender == currentOwner || approvedRecords[currentOwner][dataHash] != 0,
                    "approve hash verify failed"
                );
            } else {
                // eip712 verify
                currentOwner = ecrecover(dataHash, v, r, s);
            }
            require(currentOwner > lastOwner && isGuardian(_wallet, currentOwner), "verify failed");
            lastOwner = currentOwner;
        }
    }

    function isGuardian(address _wallet, address _guardian) public view returns (bool) {
        return walletGuardian[_wallet].guardians.isExist(_guardian);
    }

    function approveRecovery(address _wallet, address[] calldata _newOwners) external authorized(_wallet) {
        require(_newOwners.length > 0, "owners cannot be empty");
        if (!isGuardian(_wallet, sender())) {
            revert("not authorized");
        }
        //
        uint256 _nonce = nonce(_wallet);
        bytes32 recoveryHash = getSocialRecoveryHash(_wallet, _newOwners, _nonce);
        approvedRecords[sender()][recoveryHash] = 1;
        emit ApproveRecovery(_wallet, sender(), recoveryHash);
    }

    function nonce(address _wallet) public view returns (uint256 _nonce) {
        return walletRecoveryNonce[_wallet];
    }

    function threshold(address _wallet) public view returns (uint256 _threshold) {
        return walletGuardian[_wallet].threshold;
    }

    function requiredFunctions() external pure override returns (bytes4[] memory) {
        bytes4[] memory functions = new bytes4[](2);
        functions[0] = _FUNC_RESET_OWNER;
        functions[1] = _FUNC_RESET_OWNERS;
        return functions;
    }
}
