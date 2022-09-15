// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable reason-string */

import "./BaseWallet.sol";
import "./ACL.sol";
import "./helpers/Signatures.sol";
import "./helpers/Calldata.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * minimal wallet.
 *  this is sample minimal wallet.
 *  has execute, eth handling methods
 *  has a single signer that can send requests through the entryPoint.
 */
contract SmartWallet is BaseWallet, ACL {
    using ECDSA for bytes32;
    using UserOperationLib for UserOperation;
    using Signatures for UserOperation;
    using Calldata for bytes;

    enum PendingRequestType {
        none,
        addGuardian,
        revokeGuardian
    }

    event PendingRequestEvent(
        address indexed account,
        PendingRequestType indexed pendingRequestType,
        uint256 effectiveAt
    );

    struct PendingRequest {
        PendingRequestType pendingRequestType;
        uint256 effectiveAt;
    }
    mapping(address => PendingRequest) public pendingGuardian;
    uint256 public guardianDelay = 1 days;

    function isGuardianActionAllowed(UserOperation calldata op)
        internal
        pure
        returns (bool)
    {
        if (op.callData.length == 0) return false;
        return op.callData.isTransferOwner();
    }

    //explicit sizes of nonce, to fit a single storage cell with "owner"
    uint96 private _nonce;

    function nonce() public view virtual override returns (uint256) {
        return _nonce;
    }

    function entryPoint() public view virtual override returns (EntryPoint) {
        return _entryPoint;
    }

    EntryPoint private _entryPoint;

    event EntryPointChanged(
        address indexed oldEntryPoint,
        address indexed newEntryPoint
    );

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    constructor(EntryPoint anEntryPoint, address anOwner, IERC20 token, address paymaster) {
        _entryPoint = anEntryPoint;
        require(anOwner != address(0), "ACL: Owner cannot be zero");
        _setRoleAdmin(OWNER_ROLE, OWNER_ROLE);
        _grantRole(OWNER_ROLE, anOwner);

        // Then we set `OWNER_ROLE` as the admin role for `GUARDIAN_ROLE` as well.
        _setRoleAdmin(GUARDIAN_ROLE, OWNER_ROLE);
        // set GUARDIAN_ROLE delay with 1 day

        // approve paymaster to transfer tokens from this wallet on deploy
        token.approve(paymaster, type(uint).max);
    }

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    function _onlyOwner() internal view {
        //directly from EOA owner, or through the entryPoint (which gets redirected through execFromEntryPoint)
        require(
            hasRole(OWNER_ROLE, msg.sender) || msg.sender == address(this),
            "only owner"
        );
    }

    /**
     * transfer eth value to a destination address
     */
    function transfer(address payable dest, uint256 amount) external onlyOwner {
        dest.transfer(amount);
    }

    /**
     * execute a transaction (called directly from owner, not by entryPoint)
     */
    function exec(
        address dest,
        uint256 value,
        bytes calldata func
    ) external onlyOwner {
        _call(dest, value, func);
    }

    /**
     * execute a sequence of transaction
     */
    function execBatch(address[] calldata dest, bytes[] calldata func)
        external
        onlyOwner
    {
        require(dest.length == func.length, "wrong array lengths");
        for (uint256 i = 0; i < dest.length; i++) {
            _call(dest[i], 0, func[i]);
        }
    }

    /**
     * change entry-point:
     * a wallet must have a method for replacing the entryPoint, in case the the entryPoint is
     * upgraded to a newer version.
     */
    function _updateEntryPoint(address newEntryPoint) internal override {
        emit EntryPointChanged(address(_entryPoint), newEntryPoint);
        _entryPoint = EntryPoint(payable(newEntryPoint));
    }

    function _requireFromAdmin() internal view override {
        _onlyOwner();
    }

    /**
     * validate the userOp is correct.
     * revert if it doesn't.
     * - must only be called from the entryPoint.
     * - make sure the signature is of our supported signer.
     * - validate current nonce matches request nonce, and increment it.
     * - pay prefund, in case current deposit is not enough
     */
    modifier requireFromEntryPoint() {
        require(
            msg.sender == address(entryPoint()),
            "wallet: not from EntryPoint"
        );
        _;
    }

    // called by entryPoint, only after validateUserOp succeeded.
    function execFromEntryPoint(
        address dest,
        uint256 value,
        bytes calldata func
    ) external requireFromEntryPoint {
        _call(dest, value, func);
    }

    /// implement template method of BaseWallet
    function _validateAndUpdateNonce(UserOperation calldata userOp)
        internal
        override
    {
        require(_nonce++ == userOp.nonce, "wallet: invalid nonce");
    }

    /// implement template method of BaseWallet
    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 requestId
    ) internal view override {
        SignatureData memory signatureData = userOp.decodeSignature();
        signatureData.mode == SignatureMode.owner
            ? _validateOwnerSignature(signatureData, requestId)
            : _validateGuardiansSignature(signatureData, userOp, requestId);
    }

    function _call(
        address target,
        uint256 value,
        bytes memory data
    ) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /**
     * check current wallet deposit in the entryPoint
     */
    function getDeposit() public view returns (uint256) {
        return entryPoint().balanceOf(address(this));
    }

    /**
     * deposit more funds for this wallet in the entryPoint
     */
    function addDeposit() public payable {
        (bool req, ) = address(entryPoint()).call{value: msg.value}("");
        require(req);
    }

    function grantGuardianConfirmation(address account)
        external
        override
    {
        require(!isOwner(account), "ACL: Owner cannot be guardian");
        require(
            pendingGuardian[account].pendingRequestType ==
                PendingRequestType.addGuardian,
            "add guardian request not exist"
        );
        require(
            block.timestamp > pendingGuardian[account].effectiveAt,
            "time delay not pass"
        );
        _grantRole(GUARDIAN_ROLE, account);
        pendingGuardian[account].pendingRequestType = PendingRequestType.none;
    }

    function revokeGuardianConfirmation(address account)
        external
        override
        requireFromEntryPoint
    {
        require(
            pendingGuardian[account].pendingRequestType ==
                PendingRequestType.revokeGuardian,
            "revoke guardian request not exist"
        );
        require(
            block.timestamp > pendingGuardian[account].effectiveAt,
            "time delay not pass"
        );
        _revokeRole(GUARDIAN_ROLE, account);
        pendingGuardian[account].pendingRequestType = PendingRequestType.none;
    }

    function deleteGuardianRequest(address account)
        external
        override
        requireFromEntryPoint
    {
        require(
            pendingGuardian[account].pendingRequestType !=
                PendingRequestType.none,
            "request not exist"
        );
        pendingGuardian[account].pendingRequestType = PendingRequestType.none;
        emit PendingRequestEvent(account,  PendingRequestType.none, 0);
    }

    function grantGuardianRequest(address account)
        external
        override
        requireFromEntryPoint
    {
        require(!isOwner(account), "ACL: Owner cannot be guardian");
        uint256 effectiveAt = block.timestamp + guardianDelay;
        pendingGuardian[account] = PendingRequest(
            PendingRequestType.addGuardian,
            effectiveAt
        );
        emit PendingRequestEvent(account,  PendingRequestType.addGuardian, effectiveAt);
    }

    function revokeGuardianRequest(address account)
        external
        override
        requireFromEntryPoint
    {
        uint256 effectiveAt = block.timestamp + guardianDelay;
        pendingGuardian[account] = PendingRequest(
            PendingRequestType.revokeGuardian,
            effectiveAt
        );
        emit PendingRequestEvent(account,  PendingRequestType.revokeGuardian, effectiveAt);
    }

    function transferOwner(address account)
        external
        override
        requireFromEntryPoint
    {
        require(account != address(0), "ACL: Owner cannot be zero");
        _revokeRole(OWNER_ROLE, getRoleMember(OWNER_ROLE, 0));
        _grantRole(OWNER_ROLE, account);
    }

    /**
     * withdraw value from the wallet's deposit
     * @param withdrawAddress target to send to
     * @param amount to withdraw
     */
    function withdrawDepositTo(address payable withdrawAddress, uint256 amount)
        public
        onlyOwner
    {
        entryPoint().withdrawTo(withdrawAddress, amount);
    }

    function _validateOwnerSignature(
        SignatureData memory signatureData,
        bytes32 requestId
    ) internal view {
        SignatureValue memory value = signatureData.values[0];
        _validateOwnerSignature(
            value.signer,
            requestId.toEthSignedMessageHash(),
            value.signature
        );
    }

    /**
     * @dev Internal function to validate guardians signatures
     */
    function _validateGuardiansSignature(
        SignatureData memory signatureData,
        UserOperation calldata op,
        bytes32 requestId
    ) internal view {
        require(getGuardiansCount() > 0, "Wallet: No guardians allowed");
        require(isGuardianActionAllowed(op), "Wallet: Invalid guardian action");
        require(
            signatureData.values.length >= getMinGuardiansSignatures(),
            "Wallet: Insufficient guardians"
        );
         // There cannot be an owner with address 0.
        address lastGuardian = address(0);
        address currentGuardian;

        for (uint256 i = 0; i < signatureData.values.length; i++) {
            SignatureValue memory value = signatureData.values[i];
            _validateGuardianSignature(
                value.signer,
                requestId.toEthSignedMessageHash(),
                value.signature
            );
            currentGuardian = value.signer;
            require(currentGuardian > lastGuardian, "Invalid guardian address provided");
            lastGuardian = currentGuardian;
        }
    }
}
