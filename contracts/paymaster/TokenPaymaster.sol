// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ITokenPaymaster.sol";
import "../interfaces/IEntryPoint.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/IERC20.sol";
import "hardhat/console.sol";

contract TokenPaymaster is ITokenPaymaster, Ownable {
    using UserOperationLib for UserOperation;


    IEntryPoint public immutable _IEntryPoint;
    address public immutable walletFactory;

    mapping(address => IPriceOracle) private supportedToken;

    //calculated cost of the postOp
    uint256 private COST_OF_POST = 20000;

    constructor(IEntryPoint _entryPoint, address _owner, address _walletFactory) {
        require(address(_entryPoint) != address(0), "invalid etnrypoint addr");
        _IEntryPoint = _entryPoint;

        if (_owner != address(0)) {
            _transferOwnership(_owner);
        }
        require(address(_walletFactory) != address(0), "invalid etnrypoint addr");
        walletFactory = _walletFactory;
    }

    /**
     * @dev Returns the supported entrypoint.
     */
    function entryPoint() external view override returns (address) {
        return address(_IEntryPoint);
    }

    /**
     * @dev Returns true if this contract supports the given token address.
     */
    function isSupportedToken(
        address _token
    ) external view override returns (bool) {
        return address(supportedToken[_token]) != address(0);
    }

    /**
     * @dev Returns the exchange price of the token in wei.
     */
    function exchangePrice(
        address _token
    ) external view override returns (uint256 price,uint8 decimals) {
        (price, decimals) = supportedToken[_token].exchangePrice(_token);
        price = price * 99 / 100; // 1% conver chainlink `Deviation threshold`
    }

    /**
     * @dev add a token to the supported token list.
     */
    function setToken(
        address[] calldata _token,
        address[] calldata _priceOracle
    ) external onlyOwner {
        require(_token.length == _priceOracle.length, "length mismatch");
        for (uint256 i = 0; i < _token.length; i++) {
            address token = _token[i];
            address priceOracle = _priceOracle[i];
            require(token != address(0), "token cannot be zero address");
            address currentPriceOracle = address(supportedToken[token]);
            if (priceOracle == address(0)) {
                if (currentPriceOracle != address(0)) {
                    // remove token
                    delete supportedToken[token];
                    emit TokenRemoved(token);
                }
            } else {
                if (currentPriceOracle != address(0)) {
                    emit TokenRemoved(currentPriceOracle);
                }
                supportedToken[token] = IPriceOracle(priceOracle);
                emit TokenAdded(token);
            }
        }
    }

    function validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external view override returns (bytes memory context, uint256 deadline) {
        _requireFromEntryPoint();
        return _validatePaymasterUserOp(userOp, userOpHash, maxCost);
    }

    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) external override {
        _requireFromEntryPoint();
        _postOp(mode, context, actualGasCost);
    }

    function _validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 /*userOpHash*/,
        uint256 requiredPreFund   // 50U  , 20U   , 50U 
    ) private view returns (bytes memory context, uint256 deadline) {
        require(
            userOp.verificationGasLimit > 45000,
            "Paymaster: gas too low for postOp"
        );

        address sender = userOp.getSender();

        // paymasterAndData: [paymaster, token, maxCost]
        (address token, uint256 maxCost) = abi.decode(
            userOp.paymasterAndData[20:],
            (address, uint256)
        );
        IERC20 ERC20Token = IERC20(token);

        (uint256 _price,uint8 _decimals) = this.exchangePrice(token);
        uint8 tokenDecimals = IERC20(token).decimals();

        // #risk: overflow
        // exchangeRate = ( _price * 10^tokenDecimals ) / 10^_decimals / 10^18 
        uint256 exchangeRate = ( _price * 10**tokenDecimals ) / 10**_decimals; // ./10^18
        // tokenRequiredPreFund = requiredPreFund * exchangeRate / 10^18

        uint256 costOfPost = userOp.gasPrice() * COST_OF_POST;

        uint256 tokenRequiredPreFund = ((requiredPreFund + costOfPost) * exchangeRate) / 10**18;
        
        require(tokenRequiredPreFund <= maxCost, "Paymaster: maxCost too low");

        if (userOp.initCode.length != 0) {
            address factory = address(bytes20(userOp.initCode[0 : 20]));
            require(factory == walletFactory, "unknown wallet factory");
        } else {
            require(
                ERC20Token.allowance(sender, address(this)) >=
                    tokenRequiredPreFund,
                "Paymaster: not enough allowance"
            );
        }

        require(
            ERC20Token.balanceOf(sender) >= tokenRequiredPreFund,
            "Paymaster: not enough balance"
        );

        return (abi.encode(sender, token, costOfPost, exchangeRate), 0);
    }

    /**
     * post-operation handler.
     * (verified to be called only through the entryPoint)
     * @dev if subclass returns a non-empty context from validatePaymasterUserOp, it must also implement this method.
     * @param mode enum with the following options:
     *      opSucceeded - user operation succeeded.
     *      opReverted  - user op reverted. still has to pay for gas.
     *      postOpReverted - user op succeeded, but caused postOp (in mode=opSucceeded) to revert.
     *                       Now this is the 2nd call, after user's op was deliberately reverted.
     * @param context - the context value returned by validatePaymasterUserOp
     * @param actualGasCost - actual gas used so far (without this postOp call).
     */
    function _postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) private {
        (mode);
        (
            address sender,
            address payable token,
            uint256 costOfPost,
            uint256 exchangeRate
        ) = abi.decode(context, (address, address, uint256, uint256));
        uint256 tokenRequiredFund = (actualGasCost + costOfPost) * exchangeRate / 10**18;
        IERC20(token).transferFrom(sender, address(this), tokenRequiredFund);
    }

    /**
     * add a deposit for this paymaster, used for paying for transaction fees
     */
    function deposit() public payable {
        _IEntryPoint.depositTo{value: msg.value}(address(this));
    }

    /**
     * withdraw value from the deposit
     * @param withdrawAddress target to send to
     * @param amount to withdraw
     */
    function withdrawTo(
        address payable withdrawAddress,
        uint256 amount
    ) public onlyOwner {
        _IEntryPoint.withdrawTo(withdrawAddress, amount);
    }

    /**
     * add stake for this paymaster.
     * This method can also carry eth value to add to the current stake.
     * @param unstakeDelaySec - the unstake delay for this paymaster. Can only be increased.
     */
    function addStake(uint32 unstakeDelaySec) external payable onlyOwner {
        _IEntryPoint.addStake{value: msg.value}(unstakeDelaySec);
    }

    /**
     * return current paymaster's deposit on the entryPoint.
     */
    function getDeposit() public view returns (uint256) {
        return _IEntryPoint.balanceOf(address(this));
    }

    /**
     * unlock the stake, in order to withdraw it.
     * The paymaster can't serve requests once unlocked, until it calls addStake again
     */
    function unlockStake() external onlyOwner {
        _IEntryPoint.unlockStake();
    }

    /**
     * withdraw the entire paymaster's stake.
     * stake must be unlocked first (and then wait for the unstakeDelay to be over)
     * @param withdrawAddress the address to send withdrawn value.
     */
    function withdrawStake(address payable withdrawAddress) external onlyOwner {
        _IEntryPoint.withdrawStake(withdrawAddress);
    }

    /// validate the call is made from a valid entrypoint
    function _requireFromEntryPoint() private view {
        require(msg.sender == address(_IEntryPoint));
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public pure override(IERC165) returns (bool) {
        return interfaceId == type(ITokenPaymaster).interfaceId;
    }
}
