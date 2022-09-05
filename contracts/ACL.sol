pragma solidity ^0.8.12;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";


abstract contract ACL is AccessControlEnumerableUpgradeable {
    using ECDSA for bytes32;

    // solhint-disable var-name-mixedcase
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    /**
     * @dev Tells whether an account is owner or not
     */
    function isOwner(address account) public view returns (bool) {
        return hasRole(OWNER_ROLE, account);
    }

    /**
     * @dev Tells the how many owners the wallet has
     */
    function getOwnersCount() external view returns (uint256) {
        return getRoleMemberCount(OWNER_ROLE);
    }

    /**
     * @dev Tells the address of an owner at a particular index
     */
    function getOwner(uint256 index) external view returns (address) {
        return getRoleMember(OWNER_ROLE, index);
    }

    /**
     * @dev Tells the how many guardians the wallet has
     */
    function isGuardian(address account) public view returns (bool) {
        return hasRole(GUARDIAN_ROLE, account);
    }

    /**
     * @dev Tells the how many guardians the wallet has
     */
    function getGuardiansCount() public view returns (uint256) {
        return getRoleMemberCount(GUARDIAN_ROLE);
    }

    /**
     * @dev Tells whether an account is guardian or not
     */
    function getGuardian(uint256 index) external view returns (address) {
        return getRoleMember(GUARDIAN_ROLE, index);
    }

    /**
     * @dev Tells the min number amount of guardians signatures in order for an op to approved
     */
    function getMinGuardiansSignatures() public view returns (uint256) {
        return Math.ceilDiv(getGuardiansCount(), 2);
    }

    /**
     * @dev Grants guardian permissions to an account confirmation
     */
    function grantGuardianConfirmation(address account) external virtual;

    /**
     * @dev Revokes guardian permissions to an account confirmation
     */
    function revokeGuardianConfirmation(address account) external virtual;

       /**
     * @dev Grants guardian permissions to an account reqeust
     */
    function grantGuardianRequest(address account) external virtual;

    /**
     * @dev delete Request
     */
    function deleteGuardianRequest(address account) external virtual;


      /**
     * @dev Revokes guardian permissions to an account request
     */
    function revokeGuardianRequest(address account) external virtual;

    /**
     * @dev Transfers owner permissions from the owner at index #0 to another account
     */
    function transferOwner(address account) external virtual;

    /**
     * @dev Internal function to validate owner's signatures
     */
    function _validateOwnerSignature(
        address signer,
        bytes32 hash,
        bytes memory signature
    ) internal view {
        require(
            SignatureChecker.isValidSignatureNow(signer, hash, signature),
            "ACL: Invalid owner sig"
        );
        require(isOwner(signer), "ACL: Signer not an owner");
    }

    /**
     * @dev Internal function to validate guardian's signatures
     */
    function _validateGuardianSignature(
        address signer,
        bytes32 hash,
        bytes memory signature
    ) internal view {
        require(
            SignatureChecker.isValidSignatureNow(signer, hash, signature),
            "ACL: Invalid guardian sig"
        );
        require(isGuardian(signer), "ACL: Signer not a guardian");
    }
}
