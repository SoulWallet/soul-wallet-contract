// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable reason-string */

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC1271Upgradeable.sol";

/*
 */
contract GuardianMultiSigWallet is
    Initializable,
    UUPSUpgradeable,
    IERC1271Upgradeable
{
    using ECDSA for bytes32;

    mapping(address => bool) internal isGuardian;
    uint16 threshold;

    constructor() {
        _disableInitializers();
        // solhint-disable-previous-line no-empty-blocks
    }

    function initialize(address[] calldata _guardians, uint16 _threshold)
        public
        initializer
    {
        // only set guardians once
        uint256 guardianSize = _guardians.length;
        for (uint256 i = 0; i < guardianSize; i++) {
            isGuardian[_guardians[i]] = true;
        }
        threshold = _threshold;
    }

    function _authorizeUpgrade(address) internal view override {
        revert("disable upgradeable");
        // solhint-disable-previous-line no-empty-blocks
    }

    function isValidSignature(bytes32 hash, bytes memory signature)
        external
        view
        override
        returns (bytes4)
    {
        checkNSignatures(hash, signature, threshold);
        return IERC1271Upgradeable.isValidSignature.selector;
    }

    /// @dev divides bytes signature into `uint8 v, bytes32 r, bytes32 s`.
    /// @notice Make sure to perform a bounds check for @param pos, to avoid out of bounds access on @param signatures
    /// @param pos which signature to read. A prior bounds check of this parameter should be performed, to avoid out of bounds access
    /// @param signatures concatenated rsv signatures
    function signatureSplit(bytes memory signatures, uint256 pos)
        internal
        pure
        returns (
            uint8 v,
            bytes32 r,
            bytes32 s
        )
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
         referece from gnosis safe validation
    **/
    function checkNSignatures(
        bytes32 dataHash,
        bytes memory signatures,
        uint16 requiredSignatures
    ) public view {
        // Check that the provided signature data is not too short
        require(
            signatures.length >= requiredSignatures * 65,
            "signatures too short"
        );
        // There cannot be an owner with address 0.
        address lastOwner = address(0);
        address currentOwner;
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 i;
        for (i = 0; i < requiredSignatures; i++) {
            (v, r, s) = signatureSplit(signatures, i);
            if (v == 0) {
                // If v is 0 then it is a contract signature
                // When handling contract signatures the address of the contract is encoded into r
                currentOwner = address(uint160(uint256(r)));

                // Check that signature data pointer (s) is not pointing inside the static part of the signatures bytes
                // This check is not completely accurate, since it is possible that more signatures than the threshold are send.
                // Here we only check that the pointer is not pointing inside the part that is being processed
                require(
                    uint256(s) >= requiredSignatures * 65,
                    "contract signatures too short"
                );

                // Check that signature data pointer (s) is in bounds (points to the length of data -> 32 bytes)
                require(
                    uint256(s) + (32) <= signatures.length,
                    "contract signatures out of bounds"
                );

                // Check if the contract signature is in bounds: start of data is s + 32 and end is start + signature length
                uint256 contractSignatureLen;
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    contractSignatureLen := mload(add(add(signatures, s), 0x20))
                }
                require(
                    uint256(s) + 32 + contractSignatureLen <= signatures.length,
                    "contract signature wrong offset"
                );

                // Check signature
                bytes memory contractSignature;
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    // The signature data for contract signatures is appended to the concatenated signatures and the offset is stored in s
                    contractSignature := add(add(signatures, s), 0x20)
                }
                (bool success, bytes memory result) = currentOwner.staticcall(
                    abi.encodeWithSelector(
                        IERC1271Upgradeable.isValidSignature.selector,
                        dataHash,
                        contractSignature
                    )
                );
                require(
                    success &&
                        result.length == 32 &&
                        abi.decode(result, (bytes32)) ==
                        bytes32(IERC1271Upgradeable.isValidSignature.selector),
                    "contract signature invalid"
                );
            } else {
                // Default is the ecrecover flow with the provided data hash
                // Use ecrecover with the messageHash for EOA signatures
                currentOwner = ecrecover(dataHash, v, r, s);
            }
            require(
                currentOwner > lastOwner && isGuardian[currentOwner],
                "verify failed"
            );
            lastOwner = currentOwner;
        }
    }

}
