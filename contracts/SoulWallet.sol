// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable reason-string */

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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
import "./diamond/DiamondCutFacet.sol";
import "./diamond/DiamondFallback.sol";
import "./diamond/DiamondLoupeFacet.sol";

/**
 * minimal wallet.
 *  this is sample minimal wallet.
 *  has execute, eth handling methods
 *  has a single signer that can send requests through the entryPoint.
 */
contract SoulWallet is
    BaseAccount,
    Initializable,
    GuardianControl,
    LogicUpgradeControl,
    ACL,
    DefaultCallbackHandler,
    DiamondCutFacet,
    DiamondFallback,
    DiamondLoupeFacet
{
    using AccountStorage for AccountStorage.Layout;

    using ECDSA for bytes32;
    using UserOperationLib for UserOperation;
    using Signatures for UserOperation;
    using Calldata for bytes;


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

    constructor() {
        _disableInitializers();
        // solhint-disable-previous-line no-empty-blocks
    }

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
        _setGuardianWithDelay(guardian);
    }

    /**
     * @dev see guardian/GuardianControl.sol for more details
     */
    function cancelGuardian(address guardian) external onlyOwnerOrFromEntryPoint {
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
        uint256[] calldata value,
        bytes[] calldata func
    ) external onlyOwner {
        require(dest.length == func.length, "wrong array lengths");
        for (uint256 i = 0; i < dest.length; i++) {
            _call(dest[i], value[i], func[i]);
        }
    }

    // called by entryPoint, only after validateUserOp succeeded.
    function execFromEntryPoint(
        address dest,
        uint256 value,
        bytes calldata func
    ) external {
        _requireFromEntryPoint();
        _call(dest, value, func);
    }

    function execFromEntryPoint(
        address[] calldata dest,
        uint256[] calldata value,
        bytes[] calldata func
    ) external {
        _requireFromEntryPoint();
        require(dest.length == func.length && dest.length == value.length, "wrong array lengths");
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
     * validate the signature is valid for this message.
     * @param userOp validate the userOp.signature field
     * @param userOpHash convenient field: the hash of the request, to check the signature against
     *          (also hashes the entrypoint and chain-id)
     * @param aggregator the current aggregator. can be ignored by accounts that don't use aggregators
     * @return deadline the last block timestamp this operation is valid, or zero if it is valid indefinitely.
     *      Note that the validation code cannot use block.timestamp (or block.number) directly.
     */
    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        address aggregator
    ) internal virtual override returns (uint256 deadline) {
        (aggregator);
        SignatureData memory signatureData = userOp.decodeSignature();

        bytes32 _hash;
        if (signatureData.deadline == 0) {
            _hash = userOpHash;
        } else {
            _hash = keccak256(
                abi.encodePacked(userOpHash, signatureData.deadline)
            );
        }
        signatureData.mode == SignatureMode.owner
            ? _validateOwnerSignature(signatureData, _hash)
            : _validateGuardiansSignature(signatureData, userOp, _hash);

        return signatureData.deadline;
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

    function diamondCut(
        FacetCut[] memory facetCuts,
        address target,
        bytes memory data
    )  public override onlyOwnerOrFromEntryPoint{
        _diamondCut(facetCuts, target, data);
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
        bytes32 userOpHash
    ) internal view {
        require(isOwner(signatureData.signer), "Signer not an owner");

        require(
            SignatureChecker.isValidSignatureNow(
                signatureData.signer,
                userOpHash.toEthSignedMessageHash(),
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
        bytes32 userOpHash
    ) internal {
        require(isGuardianActionAllowed(op), "Wallet: Invalid guardian action");

        _validateGuardiansSignatureCallData(
            signatureData.signer,
            userOpHash.toEthSignedMessageHash(),
            signatureData.signature
        );
    }

    function getVersion() external pure returns (uint) {
        return 1;
    }

    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view returns (bytes4) {
        require(
            isOwner(hash.recover(signature)),
            "SoulWallet: Invalid signature"
        );
        return IERC1271.isValidSignature.selector;
    }

    function supportsInterface(bytes4 _interfaceID) public view override(DefaultCallbackHandler, AccessControlEnumerable) returns (bool) {
        return super.supportsInterface(_interfaceID);
    }
}
