// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable reason-string */

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "./BaseAccount.sol";
import "./helpers/Signatures.sol";
import "./helpers/Calldata.sol";
import "./guardian/GuardianControl.sol";
import "./AccountStorage.sol";
import "./ACL.sol";
import "./DefaultCallbackHandler.sol";
import "./utils/upgradeable/logicUpgradeControl.sol";
import "./utils/upgradeable/Initializable.sol";

/**
 * @author  soulwallet team.
 * @title   an implementation of the ERC4337 smart contract wallet.
 * @dev     this is the implementation contract of the soul wallet. The contract support ERC4337 which can be called by the entrypoint contract with UserOperation.
 * @notice  .
 */

contract SoulWallet is
    BaseAccount,
    Initializable,
    GuardianControl,
    LogicUpgradeControl,
    ACL,
    DefaultCallbackHandler
{
    // all state variables are stored in AccountStorage.Layout with specific storage slot to avoid storage collision
    using AccountStorage for AccountStorage.Layout;

    using ECDSA for bytes32;
    using UserOperationLib for UserOperation;
    using Signatures for bytes;
    using Signatures for bytes32;
    using Signatures for uint256;
    using Calldata for bytes;

    /**
     * @dev EIP-1271 magic value returned if the signature times out.
     */
    bytes4 constant SIGNATURE_OUT_OF_TIMERANGE = 0xffffffff;

    /**
     * @dev EIP-1271 magic value returned if the signature is invalid.
     */
    bytes4 constant SIGNATURE_INVALID = 0xfffffffe;


    /**
     * @dev Emitted when `Account` is initialized.
     */
    event AccountInitialized(
        address indexed account,
        address indexed entryPoint,
        address owner,
        uint32 upgradeDelay,
        uint32 guardianDelay,
        address guardian
    );

    /**
     * @dev this prevents initialization of the implementation contract itself
     */
    constructor() {
        _disableInitializers();
        // solhint-disable-previous-line no-empty-blocks
    }

    /**
     * @notice  initialized function to setup the soul wallet contract.
     * @dev     .
     * @param   _entryPoint  trused entrypoint.
     * @param   _owner  wallet sign key address.
     * @param   _upgradeDelay  upgrade delay which update take effect.
     * @param   _guardianDelay  guardian delay which update guardian take effect.
     * @param   _guardian  multi-sig address.
     */
    function initialize(
        IEntryPoint _entryPoint,
        address _owner,
        uint32 _upgradeDelay,
        uint32 _guardianDelay,
        address _guardian
    ) public initializer {
        // set owner
        require(_owner != address(0), "Owner cannot be zero");
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);

        // set entryPoint
        AccountStorage.Layout storage layout = AccountStorage.layout();
        layout.entryPoint = _entryPoint;

        // upgrade delay
        require(_upgradeDelay > 0, "Upgrade delay cannot be zero"); // For testing only,for release: require(upgradeDelay > 2 days, "Upgrade delay cannot be less than 2 days");
        layout.logicUpgrade.upgradeDelay = _upgradeDelay;

        // set guardian contract address and delay
        IGuardianControl.GuardianLayout storage guardianLayout = layout
            .guardian;
        require(_guardianDelay > 0, "Guardian delay cannot be zero"); // For testing only,for release: require(guardianDelay > 2 days, "Guardian delay cannot be less than 2 days");

        _setGuardianDelay(guardianLayout, _guardianDelay);
        if (_guardian != address(0)) {
            _setGuardian(guardianLayout, _guardian);
        }

        emit AccountInitialized(
            address(this),
            address(_entryPoint),
            _owner,
            _upgradeDelay,
            _guardianDelay,
            _guardian
        );
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    /**
     * @notice  return the contract nonce.
     * @dev     preventing replay attacks by ensuring that old tx are not being reused.
     * @return  uint256  .
     */
    function nonce() public view virtual override returns (uint256) {
        return AccountStorage.layout().nonce;
    }

    /**
     * @notice  return the entrypoint address.
     * @dev     should .
     * @return  IEntryPoint  .
     */
    function entryPoint() public view virtual override returns (IEntryPoint) {
        return AccountStorage.layout().entryPoint;
    }

    /**
     * @notice  only owner modifier.
     * @dev     .
     */
    modifier onlyOwner() {
        require(
            isOwner(msg.sender) || msg.sender == address(this),
            "only owner"
        );
        _;
    }

    /**
     * @notice  modifier can be called by the owner or from the entrypoint.
     * @dev     .
     */
    modifier onlyOwnerOrFromEntryPoint() {
        require(
            isOwner(msg.sender) ||
                msg.sender == address(entryPoint()) ||
                msg.sender == address(this),
            "no permission"
        );
        _;
    }

    /**
     * @dev see guardian/GuardianControl.sol for more details
     */
    function setGuardian(address guardian) external onlyOwnerOrFromEntryPoint {
        _setGuardianWithDelay(guardian);
    }

    /**
     * @dev see guardian/GuardianControl.sol for more details
     */
    function cancelGuardian(
        address guardian
    ) external onlyOwnerOrFromEntryPoint {
        _cancelGuardian(guardian);
    }

    /**
     * @dev preUpgradeTo is called before upgrading the wallet.
     */
    function preUpgradeTo(
        address newImplementation
    ) public onlyOwnerOrFromEntryPoint {
        _preUpgradeTo(newImplementation);
    }

    /**
     * @notice  ensure guardians can only be used for social recovery and cannot call other method.
     * @dev     .
     * @param   op  .
     * @return  bool .
     */
    function isGuardianActionAllowed(
        UserOperation calldata op
    ) internal pure returns (bool) {
        if (op.callData.length == 0) return false;
        return op.callData.isTransferOwner();
    }

    /**
     * @notice  transfer eth value to a destination address.
     * @dev     .
     * @param   dest  .
     * @param   amount  .
     */
    function transfer(address payable dest, uint256 amount) external onlyOwner {
        dest.transfer(amount);
    }

    /**
     * @notice  execute a transaction (called directly from owner, not by entryPoint).
     * @dev     .
     * @param   dest  .
     * @param   value  .
     * @param   func  .
     */
    function exec(
        address dest,
        uint256 value,
        bytes calldata func
    ) external onlyOwner {
        _call(dest, value, func);
    }

    /**
     * @notice  Batch multiple calls with a single operation.
     * @dev     .
     * @param   dest  .
     * @param   value  .
     * @param   func  .
     */
    function execBatch(
        address[] calldata dest,
        uint256[] calldata value,
        bytes[] calldata func
    ) external onlyOwner {
        require(
            dest.length == func.length && func.length == value.length,
            "wrong array lengths"
        );
        for (uint256 i = 0; i < dest.length; i++) {
            _call(dest[i], value[i], func[i]);
        }
    }

    /**
     * @notice  called from entrypoint and execute arbitrary call.
     * @dev     called by entryPoint, only after validateUserOp succeeded.
     * @param   dest  addresses to call.
     * @param   value  value for the call.
     * @param   func  calldata for dest address.
     */
    function execFromEntryPoint(
        address dest,
        uint256 value,
        bytes calldata func
    ) external {
        _requireFromEntryPoint();
        _call(dest, value, func);
    }

    /**
     * @notice  called from entrypoint and execute arbitrary batch call.
     * @dev     called by entryPoint, only after validateUserOp succeeded.
     * @param   dest  List of addresses to call.
     * @param   value  List of values for each subcall.
     * @param   func  call data for each `dest` address.
     */
    function execFromEntryPoint(
        address[] calldata dest,
        uint256[] calldata value,
        bytes[] calldata func
    ) external {
        _requireFromEntryPoint();
        require(
            dest.length == func.length && dest.length == value.length,
            "wrong array lengths"
        );
        for (uint256 i = 0; i < dest.length; i++) {
            _call(dest[i], value[i], func[i]);
        }
    }

    /// implement template method of BaseWallet
    function _validateAndUpdateNonce(
        UserOperation calldata userOp
    ) internal override {
        require(
            AccountStorage.layout().nonce++ == userOp.nonce,
            "wallet: invalid nonce"
        );
    }

    /**
     * @notice  validate the signature is valid for this message.
     * @param   userOp validate the userOp.signature field.
     * @param   userOpHash convenient field: the hash of the request, to check the signature against.
     * @return  validationData  returns a uint256, with is created by `_packedValidationData` and parsed by `_parseValidationData`.
     */
    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) internal virtual override returns (uint256 validationData) {
        // decode a signature from bytes
        SignatureData memory signatureData = userOp.signature.decodeSignature();

        // aggregator in signatureData.validationData must be address(0)
        require(uint160(signatureData.validationData)==0 , "wallet: aggregator not supported");

        // pack userOpHash with `signatureData.mode`,`signatureData.signer`,`signatureData.validationData`
        bytes32 _hash = userOpHash.packSignatureHash(signatureData);

        bool _sigValid;

        /*

            Note that although EIP-1271 is supported when verifying signatures, 
            but if you access storage in another contract that is not relevant 
            to you during verification, will be rejected by bundler.

         */

        if (signatureData.mode == SignatureMode.owner) {
            // owner signature
            _sigValid = _validateOwnerSignature(signatureData, _hash);
        } else {
            // guardian signature
            _sigValid = _validateGuardiansSignature(signatureData, userOp, _hash);
        }

        // equivalence code: `(sigFailed ? 1 : 0) | (uint256(validUntil) << 160) | (uint256(validAfter) << (160 + 48))`
        // validUntil and validAfter is already packed in signatureData.validationData,
        // and aggregator is address(0), so we just need to add sigFailed flag.
        return signatureData.validationData | (_sigValid ? 0 : SIG_VALIDATION_FAILED);
    }

    function _call(address target, uint256 value, bytes memory data) internal {
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

    /**
     * @notice  change the soulwallet sign key.
     * @dev     used for social recovery.
     * @param   newOwner  .
     */
    function transferOwner(
        address newOwner
    ) external override onlyOwnerOrFromEntryPoint {
        require(newOwner != address(0), "Owner cannot be zero");
        _revokeRole(DEFAULT_ADMIN_ROLE, getRoleMember(DEFAULT_ADMIN_ROLE, 0));
        _grantRole(DEFAULT_ADMIN_ROLE, newOwner);
    }

    /**
     * withdraw value from the wallet's deposit
     * @param withdrawAddress target to send to
     * @param amount to withdraw
     */
    function withdrawDepositTo(
        address payable withdrawAddress,
        uint256 amount
    ) public onlyOwner {
        entryPoint().withdrawTo(withdrawAddress, amount);
    }

    function _validateOwnerSignature(
        SignatureData memory signatureData,
        bytes32 signMessageHash
    ) internal view returns (bool success) {
        return isOwner(signatureData.signer) && 
               SignatureChecker.isValidSignatureNow(
                signatureData.signer,
                signMessageHash.toEthSignedMessageHash(),
                signatureData.signature
               );
    }

    /**
     * @dev Internal function to validate guardians signatures
     */
    function _validateGuardiansSignature(
        SignatureData memory signatureData,
        UserOperation calldata op,
        bytes32 signMessageHash
    ) internal returns (bool success) {
        return isGuardianActionAllowed(op) &&  
               _validateGuardiansSignatureCallData(
                signatureData.signer,
                signMessageHash.toEthSignedMessageHash(),
                signatureData.signature
               );
    }

    function getVersion() external pure returns (uint) {
        return 1;
    }

    /**
     * @notice  support ERC1271,  verifies whether the provided signature is valid with respect to the provided data.
     * @dev     return the correct magic value if the signature provided is valid for the provided data.
     */
    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view returns (bytes4) {
        // decode a signature from bytes
        SignatureData memory signatureData = signature.decodeSignature();

        // pack userOpHash with `signatureData.mode`,`signatureData.signer`,`signatureData.validationData`
        bytes32 _hash = hash.packSignatureHash(signatureData);

        // check signature
        bool _sigValid = _validateOwnerSignature(signatureData, _hash);

        if(!_sigValid){
            return SIGNATURE_INVALID;
        }

        if (signatureData.validationData > 0){
            // check time range if validationData is not 0 ( 0 means no time range )
            ValidationData memory validationData = signatureData.validationData.decodeValidationData();
            bool outOfTimeRange = (block.timestamp > validationData.validUntil) || (block.timestamp < validationData.validAfter);
            if(outOfTimeRange){
                return SIGNATURE_OUT_OF_TIMERANGE;
            }
        }

        return IERC1271.isValidSignature.selector;
    }

    /**
     * @notice  support ERC165, query if a contract implements an interface.
     * @dev     .
     * @param   _interfaceID  .
     * @return  bool  .
     */
    function supportsInterface(
        bytes4 _interfaceID
    )
        public
        view
        override(DefaultCallbackHandler, AccessControlEnumerable)
        returns (bool)
    {
        return super.supportsInterface(_interfaceID);
    }
}
