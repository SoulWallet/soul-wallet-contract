// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable reason-string */

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "./BaseWallet.sol";
import "./helpers/Signatures.sol";
import "./helpers/Calldata.sol";
import "./guardian/GuardianControl.sol";
import "./AccountStorage.sol";
import "./ACL.sol";
import "./utils/upgradeable/logicUpgradeControl.sol";
import "./utils/upgradeable/Initializable.sol";

/**
 * minimal wallet.
 *  this is sample minimal wallet.
 *  has execute, eth handling methods
 *  has a single signer that can send requests through the entryPoint.
 */
contract SmartWallet is
    BaseWallet,
    Initializable,
    GuardianControl,
    LogicUpgradeControl,
    ACL
{
    using AccountStorage for AccountStorage.Layout;

    using ECDSA for bytes32;
    using UserOperationLib for UserOperation;
    using Signatures for UserOperation;
    using Calldata for bytes;

    event EntryPointChanged(
        address indexed oldEntryPoint,
        address indexed newEntryPoint
    );

    constructor() {
        _disableInitializers();
        // solhint-disable-previous-line no-empty-blocks
    }

    function initialize(
        IEntryPoint _entryPoint,
        address _owner,
        uint32 _upgradeDelay,
        uint32 _guardianDelay,
        address _guardian,
        IERC20 _erc20token,
        address _paymaster
    ) public initializer {
        // set owner
        require(_owner != address(0), "Owner cannot be zero");
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);

        // set entryPoint
        AccountStorage.Layout storage layout = AccountStorage.layout();
        layout.entryPoint = _entryPoint;

        // upgrade delay
        require(_upgradeDelay > 0, "Upgrade delay cannot be zero"); //require(upgradeDelay > 1 days, "Upgrade delay cannot be less than 1 day");
        layout.logicUpgrade.upgradeDelay = _upgradeDelay;

        // set guardian contract address and delay
        IGuardianControl.GuardianLayout storage guardianLayout = layout
            .guardian;
        require(_guardianDelay > 0, "Guardian delay cannot be zero"); //require(guardianDelay > 1 days, "Guardian delay cannot be less than 1 day");

        _setGuardianDelay(guardianLayout, _guardianDelay);
        if (_guardian != address(0)) {
            _setGuardian(guardianLayout, _guardian);
        }

        // approve paymaster to transfer tokens from this wallet on deploy
        if (address(_erc20token) != address(0)) {
            require(_erc20token.approve(_paymaster, type(uint).max));
        }
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    function nonce() public view virtual override returns (uint256) {
        return AccountStorage.layout().nonce;
    }

    function entryPoint() public view virtual override returns (IEntryPoint) {
        return AccountStorage.layout().entryPoint;
    }

    modifier onlyOwner() {
        require(
            isOwner(msg.sender) || msg.sender == address(this),
            "only owner"
        );
        _;
    }

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
        _setGuardian(guardian);
    }

    /**
     * @dev preUpgradeTo is called before upgrading the wallet.
     */
    function preUpgradeTo(
        address newImplementation
    ) public onlyOwnerOrFromEntryPoint {
        _preUpgradeTo(newImplementation);
    }

    function isGuardianActionAllowed(
        UserOperation calldata op
    ) internal pure returns (bool) {
        if (op.callData.length == 0) return false;
        return op.callData.isTransferOwner();
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
    function execBatch(
        address[] calldata dest,
        bytes[] calldata func
    ) external onlyOwner {
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
        AccountStorage.Layout storage layout = AccountStorage.layout();
        emit EntryPointChanged(address(layout.entryPoint), newEntryPoint);
        layout.entryPoint = IEntryPoint(payable(newEntryPoint));
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
    function _validateAndUpdateNonce(
        UserOperation calldata userOp
    ) internal override {
        require(
            AccountStorage.layout().nonce++ == userOp.nonce,
            "wallet: invalid nonce"
        );
    }

    /// implement template method of BaseWallet
    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 requestId,
        address
    ) internal virtual override {
        SignatureData memory signatureData = userOp.decodeSignature();
        signatureData.mode == SignatureMode.owner
            ? _validateOwnerSignature(signatureData, requestId)
            : _validateGuardiansSignature(signatureData, userOp, requestId);
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
        bytes32 requestId
    ) internal view {
        require(isOwner(signatureData.signer), "Signer not an owner");

        require(
            SignatureChecker.isValidSignatureNow(
                signatureData.signer,
                requestId.toEthSignedMessageHash(),
                signatureData.signature
            ),
            "Wallet: Invalid owner sig"
        );
    }

    /**
     * @dev Internal function to validate guardians signatures
     */
    function _validateGuardiansSignature(
        SignatureData memory signatureData,
        UserOperation calldata op,
        bytes32 requestId
    ) internal {
        require(isGuardianActionAllowed(op), "Wallet: Invalid guardian action");

        _validateGuardiansSignatureCallData(
            signatureData.signer,
            requestId.toEthSignedMessageHash(),
            signatureData.signature
        );
    }

    function getVersion() external view virtual override returns (uint) {
        return 1;
    }

    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view returns (bytes4) {
        require(
            isOwner(hash.recover(signature)),
            "SmartWallet: Invalid signature"
        );
        return IERC1271.isValidSignature.selector;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
