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
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";



/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);
 
}

/**
 * minimal wallet.
 *  this is sample minimal wallet.
 *  has execute, eth handling methods
 *  has a single signer that can send requests through the entryPoint.
 */
contract SmartWallet is BaseWallet, Initializable, UUPSUpgradeable, ACL {
    using ECDSA for bytes32;
    using UserOperationLib for UserOperation;
    using Signatures for UserOperation;
    using Calldata for bytes;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    //  Name of errors                               Functions this error is to be used               
    error SmartWallet_NotZeroAddress();          // Constructor, transferOwner
    error SmartWallet_NotOwner();                // _onlyOwner
    error SmartWallet_InvalidArrayLength();      // execBatch
    error SmartWallet_InvalidEntryPoint();       // requireFromEntryPoint
    error SmartWallet_InvalidNonce();            // _validateAndUpdateNonce
    error SmartWallet_NotDelayPassed();          // grantGuardianConfirmation, revokeGuardianConfirmation
    error SmartWallet_NoAddGuardianRequest();    // grantGuardianConfirmation
    error SmartWallet_NoRevokeGuardianRequest(); // revokeGuardianConfirmation
    error SmartWallet_AddressCanNotBeGuardian(); // grantGuardianConfirmation
    error SmartWallet_NoRequestExists();         // deleteGuardianRequest
    error SmartWallet_NoGuardiansAllowed();      // _validateGuardiansSignature
    error SmartWallet_InvalidGuardianAction();   // _validateGuardiansSignature
    error SmartWallet_InsufficientGuardians();   // _validateGuardiansSignature
    error SmartWallet_InvalidAddress();          // _validateGuardiansSignature
    error SmartWallet_InvalidSignature();        // isValidSignature

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

    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    IEntryPoint private _entryPoint;

    event EntryPointChanged(
        address indexed oldEntryPoint,
        address indexed newEntryPoint
    );

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    constructor() {
        _disableInitializers();
        // solhint-disable-previous-line no-empty-blocks
    }

    function initialize(IEntryPoint anEntryPoint, address anOwner,  IERC20 token,
        address paymaster)
        public
        initializer
    {
        __AccessControlEnumerable_init();
        _entryPoint = anEntryPoint;
        if( anOwner == address(0) ){
            revert SmartWallet_NotZeroAddress();
        }
        // require(anOwner != address(0), "ACL: Owner cannot be zero");
        _setRoleAdmin(OWNER_ROLE, OWNER_ROLE);
        _grantRole(OWNER_ROLE, anOwner);

        // Then we set `OWNER_ROLE` as the admin role for `GUARDIAN_ROLE` as well.
        _setRoleAdmin(GUARDIAN_ROLE, OWNER_ROLE);

        // approve paymaster to transfer tokens from this wallet on deploy
        require(token.approve(paymaster, type(uint).max));
    }

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    function _onlyOwner() internal view {
        //directly from EOA owner, or through the entryPoint (which gets redirected through execFromEntryPoint)
        if( !(hasRole(OWNER_ROLE, msg.sender) || msg.sender == address(this))){
            revert SmartWallet_NotOwner();
        }
        // require(
        //     hasRole(OWNER_ROLE, msg.sender) || msg.sender == address(this),
        //     "only owner"
        // );
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
        if( dest.length != func.length){
            revert SmartWallet_InvalidArrayLength();
        }
        // require(dest.length == func.length, "wrong array lengths");
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
        _entryPoint = IEntryPoint(payable(newEntryPoint));
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
        if(msg.sender != address(entryPoint())){
            revert SmartWallet_InvalidNonce();
        }
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
        if(_nonce++ != userOp.nonce){
            revert SmartWallet_InvalidNonce();
        }
       
    }

    /// implement template method of BaseWallet
    function _validateSignature(UserOperation calldata userOp, bytes32 requestId, address) internal view virtual override {
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

    function grantGuardianConfirmation(address account) external override {
        if(isOwner(account)){
            revert SmartWallet_AddressCanNotBeGuardian();
        }
        
        if(pendingGuardian[account].pendingRequestType != PendingRequestType.addGuardian ){
            revert SmartWallet_NoAddGuardianRequest();
        }
        
        if( block.timestamp <=  pendingGuardian[account].effectiveAt){
            revert SmartWallet_NotDelayPassed();
        }
        
        _grantRole(GUARDIAN_ROLE, account);
        pendingGuardian[account].pendingRequestType = PendingRequestType.none;
    }

    function revokeGuardianConfirmation(address account)
        external
        override
    {
        if( pendingGuardian[account].pendingRequestType !=
                PendingRequestType.revokeGuardian  ){
                    revert SmartWallet_NoRevokeGuardianRequest();
                }
        if( ! (block.timestamp > pendingGuardian[account].effectiveAt) ){
            revert SmartWallet_NotDelayPassed();          
        }
        _revokeRole(GUARDIAN_ROLE, account);
        pendingGuardian[account].pendingRequestType = PendingRequestType.none;
    }

    function _authorizeUpgrade(address)
        internal
        view
        override
        requireFromEntryPoint
    {
        // solhint-disable-previous-line no-empty-blocks
    }

    function deleteGuardianRequest(address account)
        external
        override
        requireFromEntryPoint
    { 
        if(pendingGuardian[account].pendingRequestType ==
                PendingRequestType.none){
                    revert SmartWallet_NoRequestExists(); 
                }
        pendingGuardian[account].pendingRequestType = PendingRequestType.none;
        emit PendingRequestEvent(account, PendingRequestType.none, 0);
    }

    function grantGuardianRequest(address account)
        external
        override
        requireFromEntryPoint
    {
        if(isOwner(account)){
            revert SmartWallet_AddressCanNotBeGuardian();
        }
        uint256 effectiveAt = block.timestamp + guardianDelay;
        pendingGuardian[account] = PendingRequest(
            PendingRequestType.addGuardian,
            effectiveAt
        );
        emit PendingRequestEvent(
            account,
            PendingRequestType.addGuardian,
            effectiveAt
        );
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
        emit PendingRequestEvent(
            account,
            PendingRequestType.revokeGuardian,
            effectiveAt
        );
    }

    function transferOwner(address account)
        external
        override
        requireFromEntryPoint
    {
        if( account == address(0)){
            revert SmartWallet_NotZeroAddress();  
        }
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
        if(!(getGuardiansCount() > 0) ){
            revert SmartWallet_NoGuardiansAllowed();
        }
        
        if(!(isGuardianActionAllowed(op)) ){
            revert SmartWallet_InvalidGuardianAction();   
        }
        
        if( signatureData.values.length< getMinGuardiansSignatures()  ){
            revert SmartWallet_InsufficientGuardians();   
        }

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
            if( !(currentGuardian > lastGuardian) ){
                revert SmartWallet_InvalidAddress();
            }
            lastGuardian = currentGuardian;
        }
    }

    function getVersion() override external view virtual returns(uint){
        return 1;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
