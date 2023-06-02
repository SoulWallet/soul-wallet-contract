// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

// Import the required libraries and contracts
import "@account-abstraction/contracts/core/BasePaymaster.sol";
import "@account-abstraction/contracts/core/Helpers.sol";
import "@account-abstraction/contracts/interfaces/UserOperation.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IOracle.sol";
import "@account-abstraction/contracts/core/EntryPoint.sol";

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

    // Trusted token approve gas cost
    uint256 private constant _SAFE_APPROVE_GAS_COST = 50000;

    address public immutable WALLET_FACTORY;

    mapping(address => TokenSetting) public supportedToken;

    event ConfigUpdated(address token, address oracle, uint32 priceMarkup);

    event UserOperationSponsored(address indexed user, address token, uint256 actualTokenNeeded, uint256 actualGasCost);

    constructor(IEntryPoint _entryPoint, address _owner, address _walletFactory) BasePaymaster(_entryPoint) {
        transferOwnership(_owner);
        require(address(_walletFactory) != address(0), "Paymaster: invalid etnrypoint addr");
        WALLET_FACTORY = _walletFactory;
    }

    function setToken(
        address[] calldata _tokens,
        address[] calldata _tokenOracles,
        uint32[] calldata _priceMarkups
    ) external onlyOwner {
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
            supportedToken[_token].tokenDecimals =  IERC20Metadata(_token).decimals();

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
            _validateConstructor(userOp, token, tokenRequiredPreFund);
        } else {
            require(
                ERC20Token.allowance(sender, address(this)) >= tokenRequiredPreFund, "Paymaster: not enough allowance"
            );
        }

        require(ERC20Token.balanceOf(sender) >= tokenRequiredPreFund, "Paymaster: not enough balance");

        return (abi.encode(sender, token, costOfPost, exchangeRate), 0);
    }

    function _validateConstructor(UserOperation calldata userOp, address token, uint256 tokenRequiredPreFund)
        internal
        view
    {
        address factory = address(bytes20(userOp.initCode));
        require(factory == WALLET_FACTORY, "Paymaster: unknown wallet factory");
        require(
            bytes4(userOp.callData)
                == bytes4(0x2763604f /* 0x2763604f execFromEntryPoint(address[],uint256[],bytes[]) */ ),
            "invalid callData"
        );
        (address[] memory dest, uint256[] memory value, bytes[] memory func) =
            abi.decode(userOp.callData[4:], (address[], uint256[], bytes[]));
        require(dest.length == value.length && dest.length == func.length, "Paymaster: invalid callData");

        address _destAddress = address(0);
        for (uint256 i = 0; i < dest.length; i++) {
            address destAddr = dest[i];
            require(isSupportToken(token), "Paymaster: token not support");
            if (destAddr == token) {
                (address spender, uint256 amount) = _decodeApprove(func[i]);
                require(spender == address(this), "Paymaster: invalid spender");
                require(amount >= tokenRequiredPreFund, "Paymaster: snot enough approve");
            }
            require(destAddr > _destAddress, "Paymaster: duplicate");
            _destAddress = destAddr;
        }
        // callGasLimit
        uint256 callGasLimit = dest.length * _SAFE_APPROVE_GAS_COST;
        require(userOp.callGasLimit >= callGasLimit, "Paymaster: gas too low for postOp");
    }

    function _decodeApprove(bytes memory func) private pure returns (address spender, uint256 value) {
        // 0x095ea7b3 approve(address,uint256)
        // 0x095ea7b3   address  uint256
        // ____4_____|____32___|___32__

        require(bytes4(func) == bytes4(0x095ea7b3), "invalid approve func");
        assembly {
            spender := mload(add(func, 36)) // 32 + 4
            value := mload(add(func, 68)) // 32 + 4 +32
        }
    }


    function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost) internal override {
        if (mode == PostOpMode.postOpReverted) {
            return; // Do nothing here to not revert the whole bundle and harm reputation
        }
        (address sender, address payable token, uint256 costOfPost, uint256 exchangeRate) =
            abi.decode(context, (address, address, uint256, uint256));
        uint256 tokenRequiredFund =
            (actualGasCost + costOfPost) * supportedToken[token].priceMarkup * exchangeRate / (1e18 * PRICE_DENOMINATOR);

        IERC20Metadata(token).safeTransferFrom(sender, address(this), tokenRequiredFund);
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
