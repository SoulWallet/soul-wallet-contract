// SPDX-License-Identifier: GPL-3.0
/*
This code is based on the pimlicolabs erc20-paymaster-contracts found at https://github.com/pimlicolabs/erc20-paymaster-contracts.
Credit to the original authors and contributors.
*/
pragma solidity ^0.8.0;

// Import the required libraries and contracts
import "@account-abstraction/contracts/core/BasePaymaster.sol";
import "@account-abstraction/contracts/core/Helpers.sol";
import "@account-abstraction/contracts/interfaces/UserOperation.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IOracle.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";

struct TokenSetting {
    uint256 tokenDecimals;
    IOracle tokenOracle;
    uint192 previousPrice; // The cached token price from the Oracle
    uint32 priceMarkup; // The price markup percentage applied to the token price (1e6 = 100%)
}

contract ERC20Paymaster is BasePaymaster {
    using UserOperationLib for UserOperation;
    using SafeERC20 for IERC20Metadata;

    uint256 public constant PRICE_DENOMINATOR = 1e6;
    // calculated cost of the postOp
    uint256 public constant COST_OF_POST = 40000;
    // This is the threshold check in the active wallet constructor for the maximum sponsor fund.
    // It prevents a malicious user from draining the Paymaster's deposit in a single user operation.
    uint256 public constant MAX_ALLOW_SPONSOR_FUND_ACTIVE_WALLET = 0.1 ether;

    // Trusted token approve gas cost
    uint256 private constant _SAFE_APPROVE_GAS_COST = 50000;

    address public immutable WALLET_FACTORY;

    mapping(address => TokenSetting) public supportedToken;

    event ConfigUpdated(address token, address oracle, uint32 priceMarkup);

    event UserOperationSponsored(address indexed user, address token, uint256 actualTokenNeeded, uint256 actualGasCost);

    constructor(IEntryPoint _entryPoint, address _owner, address _walletFactory) BasePaymaster(_entryPoint, _owner) {
        require(address(_walletFactory) != address(0), "Paymaster: invalid etnrypoint addr");
        WALLET_FACTORY = _walletFactory;
    }

    function setToken(address[] calldata _tokens, address[] calldata _tokenOracles, uint32[] calldata _priceMarkups)
        external
        onlyOwner
    {
        require(
            _tokens.length == _tokenOracles.length && _tokenOracles.length == _priceMarkups.length,
            "Paymaster: length mismatch"
        );
        for (uint256 i = 0; i < _tokens.length; i++) {
            address _token = _tokens[i];
            address _tokenOracle = _tokenOracles[i];
            uint32 _priceMarkup = _priceMarkups[i];
            require(_token != address(0) && _tokenOracle != address(0), "Paymaster: cannot be zero address");
            require(_priceMarkup <= 120e4, "Paymaster: price markup too high");
            require(_priceMarkup >= 1e6, "Paymaster: price markeup too low");
            require(IOracle(_tokenOracle).decimals() == 8, "Paymaster: token oracle decimals must be 8");
            supportedToken[_token].priceMarkup = _priceMarkup;
            supportedToken[_token].tokenOracle = IOracle(_tokenOracle);
            supportedToken[_token].tokenDecimals = IERC20Metadata(_token).decimals();
            emit ConfigUpdated(_token, _tokenOracle, _priceMarkup);
        }
    }

    function withdrawToken(address token, address to, uint256 amount) external onlyOwner {
        IERC20Metadata(token).transfer(to, amount);
    }

    function updatePrice(address token) external {
        require(isSupportToken(token), "Paymaster: token not support");
        uint192 tokenPrice = fetchPrice(supportedToken[token].tokenOracle);
        supportedToken[token].previousPrice = tokenPrice;
    }

    function isSupportToken(address token) public view returns (bool) {
        return address(supportedToken[token].tokenOracle) != address(0);
    }

    function _validatePaymasterUserOp(UserOperation calldata userOp, bytes32, uint256 requiredPreFund)
        internal
        override
        returns (bytes memory context, uint256 validationResult)
    {
        require(userOp.verificationGasLimit > 45000, "Paymaster: gas too low for postOp");

        address sender = userOp.getSender();

        // paymasterAndData: [paymaster, token, maxCost]
        // The length check prevents the user from add exceeding calldata, which could drain paymaster deposits in entrypoint
        require(userOp.paymasterAndData.length == 84, "invalid data length");
        (address token, uint256 maxCost) = abi.decode(userOp.paymasterAndData[20:], (address, uint256));
        require(isSupportToken(token), "Paymaster: token not support");
        IERC20Metadata ERC20Token = IERC20Metadata(token);

        uint256 cachedPrice = supportedToken[token].previousPrice;
        require(cachedPrice != 0, "Paymaster: price not set");

        uint256 exchangeRate = (cachedPrice * 10 ** supportedToken[token].tokenDecimals) / 10 ** 8;
        // tokenRequiredPreFund = requiredPreFund * exchangeRate / 10^18

        uint256 costOfPost = userOp.gasPrice() * COST_OF_POST;

        uint256 tokenRequiredPreFund = (requiredPreFund + costOfPost) * supportedToken[token].priceMarkup * exchangeRate
            / (1e18 * PRICE_DENOMINATOR);

        require(tokenRequiredPreFund <= maxCost, "Paymaster: maxCost too low");

        if (userOp.initCode.length != 0) {
            // This operation prevents a malicious user from draining the Paymaster's deposit in a single active wallet user operation.
            // However, it doesn't prevent a user from sending multiple active wallet user operations to drain the Paymaster's deposit.
            // It does, however, add overhead for the attacker.
            require(requiredPreFund < MAX_ALLOW_SPONSOR_FUND_ACTIVE_WALLET, "Paymaster: maxCost too high");
            require(ERC20Token.balanceOf(sender) >= tokenRequiredPreFund, "Paymaster: not enough balance");
            _validateConstructor(userOp, token, tokenRequiredPreFund);
        } else {
            ERC20Token.safeTransferFrom(sender, address(this), tokenRequiredPreFund);
        }

        return (abi.encode(sender, token, costOfPost, exchangeRate, tokenRequiredPreFund), 0);
    }

    /*
    * @notice This function is currently in the testing phase.
    * @dev The Paymaster is potentially vulnerable to attacks, which poses a risk of reputation loss.
    * The approval check in this context does not guarantee that the Paymaster will successfully receive the corresponding tokens via transferFrom in subsequent _postOp operations.
    */
    function _validateConstructor(UserOperation calldata userOp, address token, uint256 tokenRequiredPreFund)
        internal
        view
    {
        address factory = address(bytes20(userOp.initCode));
        require(factory == WALLET_FACTORY, "Paymaster: unknown wallet factory");
        require(
            /*
            * 0x18dfb3c7 executeBatch(address[],bytes[])
            * 0x47e1da2a executeBatch(address[],uint256[],bytes[])
            */
            bytes4(userOp.callData) == bytes4(0x47e1da2a) || bytes4(userOp.callData) == bytes4(0x18dfb3c7),
            "invalid callData"
        );
        address[] memory dest;
        bytes[] memory func;
        if (bytes4(userOp.callData) == bytes4(0x47e1da2a)) {
            (dest,, func) = abi.decode(userOp.callData[4:], (address[], uint256[], bytes[]));
        } else {
            (dest, func) = abi.decode(userOp.callData[4:], (address[], bytes[]));
        }

        require(dest.length == func.length, "Paymaster: invalid callData length");
        require(isSupportToken(token), "Paymaster: token not support");
        bool checkAllowance = false;
        for (uint256 i = 0; i < dest.length; i++) {
            address destAddr = dest[i];
            // check it contains approve operation, 0x095ea7b3 approve(address,uint256)
            if (destAddr == token && bytes4(func[i]) == bytes4(0x095ea7b3)) {
                (address spender, uint256 amount) = _decodeApprove(func[i]);
                require(spender == address(this), "Paymaster: invalid spender");
                require(amount >= tokenRequiredPreFund, "Paymaster: not enough approve");
                checkAllowance = true;
                break;
            }
        }
        require(checkAllowance, "no approve found");
        // callGasLimit
        uint256 callGasLimit = dest.length * _SAFE_APPROVE_GAS_COST;
        require(userOp.callGasLimit >= callGasLimit, "Paymaster: gas too low for postOp");
    }

    function _decodeApprove(bytes memory func) private pure returns (address spender, uint256 value) {
        // 0x095ea7b3   address  uint256
        // ____4_____|____32___|___32__
        assembly {
            spender := mload(add(func, 36)) // 32 + 4
            value := mload(add(func, 68)) // 32 + 4 +32
        }
    }

    function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost) internal override {
        if (mode == PostOpMode.postOpReverted) {
            return; // Do nothing here to not revert the whole bundle and harm reputation
        }
        (address sender, address payable token, uint256 costOfPost, uint256 exchangeRate, uint256 tokenRequiredPreFund)
        = abi.decode(context, (address, address, uint256, uint256, uint256));
        uint256 tokenRequiredFund =
            (actualGasCost + costOfPost) * supportedToken[token].priceMarkup * exchangeRate / (1e18 * PRICE_DENOMINATOR);
        // refund unsed precharge token
        if (tokenRequiredPreFund > tokenRequiredFund) {
            IERC20Metadata(token).safeTransfer(sender, tokenRequiredPreFund - tokenRequiredFund);
        }
        // update oracle
        uint192 lasestTokenPrice = fetchPrice(supportedToken[token].tokenOracle);
        supportedToken[token].previousPrice = lasestTokenPrice;
        emit UserOperationSponsored(sender, token, tokenRequiredFund, actualGasCost);
    }

    function fetchPrice(IOracle _oracle) internal view returns (uint192 price) {
        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) = _oracle.latestRoundData();
        require(answer > 0, "Paymaster: Chainlink price <= 0");
        require(updatedAt >= (block.timestamp - 2 days), "Paymaster: Incomplete round");
        require(answeredInRound >= roundId, "Paymaster: Stale price");
        price = uint192(int192(answer));
    }
}
